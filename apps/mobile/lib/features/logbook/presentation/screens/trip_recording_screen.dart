import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/map_controls.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/position_indicator.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/navigation_hud.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/recording_controls.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_completion_dialog.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';
import 'package:navis_mobile/features/ports/presentation/widgets/port_markers_layer.dart';

class TripRecordingScreen extends ConsumerStatefulWidget {
  const TripRecordingScreen({
    super.key,
    required this.boatId,
    this.tripId,
    this.isRegatta = false,
    this.autoStart = false,
    this.departurePort,
  });

  final String boatId;

  /// Optional pre-selected departure port (e.g. starting a regatta from an
  /// event). Used as the trip's departure instead of the home-port fallback.
  final String? departurePort;

  /// When set, records into this existing (already-started) trip instead of
  /// creating a new one — used for group regattas after the safety checklist.
  final String? tripId;

  /// Whether [tripId] refers to a group regatta (affects cancel behaviour).
  final bool isRegatta;

  /// Begin recording immediately on open (e.g. after the pre-trip checklist).
  final bool autoStart;

  @override
  ConsumerState<TripRecordingScreen> createState() =>
      _TripRecordingScreenState();
}

class _TripRecordingScreenState extends ConsumerState<TripRecordingScreen>
    with WidgetsBindingObserver {
  TripStatus _status = TripStatus.completed;
  final List<TrackPoint> _trackPoints = [];
  final List<TrackPoint> _pendingUpload = [];
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _startTime;
  double _totalDistance = 0;
  double _maxSpeed = 0;
  double _currentSpeed = 0;
  double? _currentHeading;
  Timer? _elapsedTimer;
  Timer? _uploadTimer;
  Duration _elapsed = Duration.zero;
  Trip? _createdTrip;
  bool _saving = false;
  double? _gpsAccuracy;
  LatLng? _currentPosition;
  bool _followMode = true;
  bool _showSeamarks = true;
  bool _showPorts = true;
  final MapController _mapController = MapController();

  static const _uploadIntervalSeconds = 60;
  static const _defaultCenter = LatLng(39.57, 2.63);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _acquireInitialPosition();
    // Auto-start when coming from the checklist (regatta trip or solo autostart).
    if (widget.tripId != null || widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRecording();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    _uploadTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _status == TripStatus.recording) {
      _ensureLocationStream();
    }
  }

  Future<void> _acquireInitialPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = LatLng(
            position.latitude,
            position.longitude,
          );
        });
        _mapController.move(_currentPosition!, 14);
      }
    } catch (_) {}
  }

  void _ensureLocationStream() {
    if (_positionSubscription != null) return;
    _startLocationStream();
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();

    final locationSettings = _platformLocationSettings();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPositionUpdate);
  }

  LocationSettings _platformLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Navis is recording your trip',
          notificationText: 'GPS tracking is active',
          notificationIcon: AndroidResource(name: 'ic_launcher'),
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        activityType: ActivityType.otherNavigation,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  void _onPositionUpdate(Position position) {
    final newPos = LatLng(position.latitude, position.longitude);
    final speedKn = position.speed * 1.94384;

    setState(() {
      _currentPosition = newPos;
      _gpsAccuracy = position.accuracy;
      _currentSpeed = speedKn;
      _currentHeading =
          position.heading >= 0 ? position.heading : _currentHeading;
    });

    if (_status != TripStatus.recording) return;

    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      speedKnots: speedKn,
    );

    setState(() {
      if (_trackPoints.isNotEmpty) {
        final last = _trackPoints.last;
        _totalDistance += DistanceUtils.calculateDistance(
          last.latitude,
          last.longitude,
          point.latitude,
          point.longitude,
        );
      }

      if (speedKn > _maxSpeed) _maxSpeed = speedKn;

      _trackPoints.add(point);
      _pendingUpload.add(point);
    });

    if (_followMode) {
      try {
        _mapController.move(newPos, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  Future<void> _startRecording() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationPermissionRequired,
              ),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.locationPermissionDenied,
            ),
          ),
        );
      }
      return;
    }

    _startLocationStream();

    setState(() {
      _status = TripStatus.recording;
      _startTime = DateTime.now();
      _trackPoints.clear();
      _pendingUpload.clear();
      _totalDistance = 0;
      _maxSpeed = 0;
      _currentSpeed = 0;
      _elapsed = Duration.zero;
      _followMode = true;
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == TripStatus.recording) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });

    _uploadTimer = Timer.periodic(
      const Duration(seconds: _uploadIntervalSeconds),
      (_) => _uploadPendingPoints(),
    );

    unawaited(HapticFeedback.mediumImpact());

    // Recording into an existing regatta trip: it already exists on the server.
    if (widget.tripId != null) {
      setState(() => _createdTrip = Trip(
            id: widget.tripId!,
            boatId: widget.boatId,
            departurePort: '',
            departureTime: _startTime!,
            status: TripStatus.recording,
          ));
      return;
    }

    try {
      final repo = ref.read(tripRepositoryProvider);
      // Prefer the port chosen up front (e.g. starting from an event).
      String departureName =
          (widget.departurePort != null && widget.departurePort!.isNotEmpty)
              ? widget.departurePort!
              : 'Unknown';
      if (departureName == 'Unknown' && _currentPosition != null) {
        try {
          final portRepo = ref.read(portRepositoryProvider);
          final ports = await portRepo.getNearby(
            lat: _currentPosition!.latitude,
            lon: _currentPosition!.longitude,
            limit: 1,
          );
          if (ports.isNotEmpty) departureName = ports.first.name;
        } catch (_) {}
      }

      // Fall back to the boat's home port rather than leaving it "Unknown".
      if (departureName == 'Unknown') {
        final boats = ref.read(boatsProvider).valueOrNull ?? const [];
        for (final b in boats) {
          if (b.id == widget.boatId &&
              b.homePort != null &&
              b.homePort!.isNotEmpty) {
            departureName = b.homePort!;
            break;
          }
        }
      }

      final trip = await repo.createTrip(Trip(
        id: '',
        boatId: widget.boatId,
        departurePort: departureName,
        departureTime: _startTime!,
        status: TripStatus.recording,
      ));
      setState(() => _createdTrip = trip);
    } catch (e) {
      debugPrint('Failed to create trip on server: $e');
    }
  }

  void _pauseRecording() {
    setState(() => _status = TripStatus.paused);
    _positionSubscription?.cancel();
    _positionSubscription = null;
    HapticFeedback.lightImpact();
  }

  void _resumeRecording() {
    setState(() {
      _status = TripStatus.recording;
      _followMode = true;
    });
    _startLocationStream();
    HapticFeedback.lightImpact();
  }

  Future<void> _cancelRecording() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await _confirmDiscard(
      title: l.cancelTrip,
      message:
          widget.isRegatta ? l.cancelTripRegattaWarning : l.cancelTripWarning,
      confirmLabel: l.cancelTrip,
    );
    if (confirmed) await _discardTripAndPop();
  }

  /// Leave the map without saving the trip. Available while recording so the
  /// user is never "trapped" in the map — discards the in-progress recording.
  Future<void> _exitWithoutSaving() async {
    if (_status == TripStatus.completed) {
      context.pop();
      return;
    }
    final l = AppLocalizations.of(context)!;
    final confirmed = await _confirmDiscard(
      title: l.exitWithoutSaving,
      message: widget.isRegatta ? l.exitRegattaWarning : l.exitTripWarning,
      confirmLabel: l.exitWithoutSaving,
    );
    if (confirmed) await _discardTripAndPop();
  }

  Future<bool> _confirmDiscard({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title:
            Text(title, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.keepGoing),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel,
                style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Stops timers/streams, discards the trip on the server (delete for solo,
  /// revert to planned for a regatta) and leaves the screen.
  Future<void> _discardTripAndPop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _uploadTimer?.cancel();

    try {
      if (_createdTrip != null) {
        if (widget.isRegatta) {
          await ref
              .read(regattaRepositoryProvider)
              .revertToPlanned(_createdTrip!.id);
          ref.invalidate(regattaProvider(_createdTrip!.id));
        } else {
          await ref.read(tripRepositoryProvider).deleteTrip(_createdTrip!.id);
        }
      }
    } catch (_) {}

    if (!mounted) return;
    unawaited(HapticFeedback.heavyImpact());
    context.pop();
  }

  Future<void> _stopRecording() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _uploadTimer?.cancel();

    unawaited(HapticFeedback.heavyImpact());

    if (!mounted) return;

    final ports = ref.read(allPortsProvider).valueOrNull;

    // For group regattas, pre-fill the crew with members who RSVP'd "going".
    var crewSuggestions = const <String>[];
    if (widget.isRegatta && widget.tripId != null) {
      try {
        final participants =
            await ref.read(regattaParticipantsProvider(widget.tripId!).future);
        crewSuggestions = participants
            .where((p) => p.rsvp == 'going' && p.name.trim().isNotEmpty)
            .map((p) => p.name)
            .toList(growable: false);
      } catch (_) {
        // Best effort: no suggestions if participants can't be loaded.
      }
    }
    if (!mounted) return;

    final completionData = await showDialog<TripCompletionData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TripCompletionDialog(
        distanceNm: _totalDistance,
        duration: _elapsed,
        avgSpeed: _elapsed.inSeconds > 0
            ? _totalDistance / (_elapsed.inSeconds / 3600)
            : null,
        nearbyPorts: ports ?? [],
        initialCrew: crewSuggestions,
        crewSuggestions: crewSuggestions,
        startLat: _trackPoints.isNotEmpty
            ? _trackPoints.first.latitude
            : _currentPosition?.latitude,
        startLon: _trackPoints.isNotEmpty
            ? _trackPoints.first.longitude
            : _currentPosition?.longitude,
        endLat: _currentPosition?.latitude,
        endLon: _currentPosition?.longitude,
      ),
    );

    if (completionData == null) {
      _startLocationStream();
      setState(() => _status = TripStatus.recording);
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_status == TripStatus.recording) {
          setState(() {
            _elapsed = DateTime.now().difference(_startTime!);
          });
        }
      });
      _uploadTimer = Timer.periodic(
        const Duration(seconds: _uploadIntervalSeconds),
        (_) => _uploadPendingPoints(),
      );
      return;
    }

    setState(() {
      _status = TripStatus.completed;
      _saving = true;
    });

    try {
      final repo = ref.read(tripRepositoryProvider);

      await _uploadPendingPoints();

      if (_createdTrip != null) {
        if (completionData.departurePort != null &&
            completionData.departurePort != _createdTrip!.departurePort) {
          await repo.updateTrip(_createdTrip!.copyWith(
            departurePort: completionData.departurePort,
          ));
        }
        await repo.completeTrip(
          _createdTrip!.id,
          arrivalPort: completionData.arrivalPort,
          distanceNm: _totalDistance,
          engineHours: completionData.engineHours,
          fuelConsumedL: completionData.fuelConsumedL,
        );
      } else {
        final trip = await repo.createTrip(Trip(
          id: '',
          boatId: widget.boatId,
          departurePort: completionData.departurePort ?? 'Unknown',
          departureTime: _startTime!,
          arrivalPort: completionData.arrivalPort,
          arrivalTime: DateTime.now(),
          distanceNm: _totalDistance,
          maxSpeedKnots: _maxSpeed,
          avgSpeedKnots: _elapsed.inSeconds > 0
              ? _totalDistance / (_elapsed.inSeconds / 3600)
              : null,
          notes: completionData.notes,
          engineHours: completionData.engineHours,
          fuelConsumedL: completionData.fuelConsumedL,
          crewMembers: completionData.crewMembers,
          trackPoints: _trackPoints,
        ));
        if (_trackPoints.isNotEmpty) {
          await repo.addTrackPoints(trip.id, _trackPoints);
        }
      }

      ref.invalidate(boatTripsProvider(widget.boatId));
      // Refresh the regatta so its detail no longer shows "en curso".
      if (widget.isRegatta && _createdTrip != null) {
        ref.invalidate(regattaProvider(_createdTrip!.id));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.tripSaved)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context)!.failedToSaveTrip}: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadPendingPoints() async {
    if (_pendingUpload.isEmpty || _createdTrip == null) return;

    final toUpload = List<TrackPoint>.from(_pendingUpload);
    _pendingUpload.clear();

    try {
      final repo = ref.read(tripRepositoryProvider);
      await repo.addTrackPoints(_createdTrip!.id, toUpload);
    } catch (e) {
      _pendingUpload.insertAll(0, toUpload);
      debugPrint('Failed to upload track points: $e');
    }
  }

  void _centerOnPosition() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 14);
      setState(() => _followMode = true);
    }
  }

  List<Polyline> _buildTrackPolylines() {
    if (_trackPoints.length < 2) return [];

    final polylines = <Polyline>[];
    for (var i = 0; i < _trackPoints.length - 1; i++) {
      final speed = _trackPoints[i].speedKnots ?? 0;
      final color = switch (speed) {
        < 3 => AppColors.cyan,
        < 6 => AppColors.green,
        < 12 => AppColors.amber,
        _ => AppColors.red,
      };

      polylines.add(
        Polyline(
          points: [
            LatLng(
              _trackPoints[i].latitude,
              _trackPoints[i].longitude,
            ),
            LatLng(
              _trackPoints[i + 1].latitude,
              _trackPoints[i + 1].longitude,
            ),
          ],
          color: color,
          strokeWidth: 3.5,
        ),
      );
    }
    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _status != TripStatus.completed;
    final center = _currentPosition ?? _defaultCenter;

    final nearbyPorts = _showPorts ? ref.watch(allPortsProvider) : null;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: _saving
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.cyan),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.savingTrip,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                RepaintBoundary(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onPositionChanged: (_, hasGesture) {
                        if (hasGesture) {
                          setState(() => _followMode = false);
                        }
                      },
                    ),
                    children: [
                      OpenSeaMapTileProvider.baseLayer,
                      if (_showSeamarks) OpenSeaMapTileProvider.seamarkLayer,
                      if (_trackPoints.length >= 2)
                        PolylineLayer(
                          polylines: _buildTrackPolylines(),
                        ),
                      if (nearbyPorts case AsyncData(:final value))
                        PortMarkersLayer(
                          ports: value,
                          userPosition: _currentPosition,
                        ),
                      if (_currentPosition != null)
                        PositionIndicator(
                          position: _currentPosition!,
                        ),
                      if (_trackPoints.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                _trackPoints.first.latitude,
                                _trackPoints.first.longitude,
                              ),
                              width: 14,
                              height: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.green
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (isRecording)
                  NavigationHud(
                    speedKnots: _currentSpeed,
                    heading: _currentHeading,
                    distanceNm: _totalDistance,
                    elapsed: _elapsed,
                    gpsAccuracy: _gpsAccuracy,
                  ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: _GlassIconButton(
                    icon: isRecording ? Icons.close : Icons.arrow_back,
                    onPressed:
                        isRecording ? _exitWithoutSaving : () => context.pop(),
                    semanticLabel: isRecording
                        ? AppLocalizations.of(context)!.exitWithoutSaving
                        : AppLocalizations.of(context)!.goBack,
                  ),
                ),
                MapControls(
                  onZoomIn: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                  onZoomOut: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                  onCenterGps: _centerOnPosition,
                  onToggleLayers: () => setState(
                    () => _showSeamarks = !_showSeamarks,
                  ),
                  showSeamarks: _showSeamarks,
                  onTogglePorts: () => setState(
                    () => _showPorts = !_showPorts,
                  ),
                  showPorts: _showPorts,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  child: RecordingControls(
                    status: _status,
                    onStart: _startRecording,
                    onPause: _pauseRecording,
                    onResume: _resumeRecording,
                    onStop: _stopRecording,
                    onCancel: _cancelRecording,
                  ),
                ),
              ],
            ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}
