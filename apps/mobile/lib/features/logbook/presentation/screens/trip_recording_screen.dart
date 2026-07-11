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
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/map_controls.dart';
import 'package:navis_mobile/features/charts/presentation/widgets/position_indicator.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/navigation_hud.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/recording_controls.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_completion_dialog.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';
import 'package:navis_mobile/features/ports/presentation/widgets/port_markers_layer.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// Map UI for trip recording. All recording logic (GPS stream, per-fix sqlite
/// persistence, batched upload, stats, completion) lives in
/// [TripRecordingNotifier] — this screen renders state and forwards intents,
/// so navigating away or killing the app never loses the recording.
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
  bool _followMode = true;
  bool _showSeamarks = true;
  bool _showPorts = true;
  final MapController _mapController = MapController();

  // Incremental polyline cache: only the segments for NEW points are built on
  // rebuild instead of the whole track every frame.
  final List<Polyline> _cachedPolylines = [];
  int _cachedPointCount = 0;

  static const _defaultCenter = LatLng(39.57, 2.63);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _acquireInitialPosition();
    // Auto-start when coming from the checklist (regatta trip or solo
    // autostart) unless a recording is already running (resume navigation).
    final alreadyActive = ref.read(tripRecordingProvider).isActive;
    if (!alreadyActive && (widget.tripId != null || widget.autoStart)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRecording();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(tripRecordingProvider.notifier).ensureLocationStream();
    }
  }

  Future<void> _acquireInitialPosition() async {
    if (ref.read(tripRecordingProvider).currentPosition != null) return;
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          14,
        );
      }
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    final l = AppLocalizations.of(context)!;
    final result = await ref.read(tripRecordingProvider.notifier).start(
          boatId: widget.boatId,
          tripId: widget.tripId,
          isRegatta: widget.isRegatta,
          departurePort: widget.departurePort,
        );
    if (!mounted) return;

    switch (result) {
      case RecordingStartResult.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.locationPermissionRequired)),
        );
        return;
      case RecordingStartResult.permissionDeniedForever:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.locationPermissionDenied)),
        );
        return;
      case RecordingStartResult.started:
        break;
    }

    setState(() => _followMode = true);
    _resetPolylineCache();
    unawaited(HapticFeedback.mediumImpact());

    // iOS records in the background only with the "Always" permission; a
    // when-in-use grant works with the screen on, so just advise once.
    if (Platform.isIOS) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.backgroundLocationAdvice)),
        );
      }
    }
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
    if (!ref.read(tripRecordingProvider).isActive) {
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

  Future<void> _discardTripAndPop() async {
    await ref.read(tripRecordingProvider.notifier).discard();
    if (!mounted) return;
    unawaited(HapticFeedback.heavyImpact());
    context.pop();
  }

  Future<void> _stopRecording() async {
    final notifier = ref.read(tripRecordingProvider.notifier);
    final recording = ref.read(tripRecordingProvider);

    // Freeze the stream while the completion dialog is open.
    notifier.pause();
    unawaited(HapticFeedback.heavyImpact());

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

    final points = recording.trackPoints;
    final completionData = await showDialog<TripCompletionData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TripCompletionDialog(
        distanceNm: recording.totalDistanceNm,
        duration: recording.startTime != null
            ? DateTime.now().difference(recording.startTime!)
            : Duration.zero,
        avgSpeed: recording.avgSpeedKnots,
        nearbyPorts: ports ?? [],
        initialCrew: crewSuggestions,
        crewSuggestions: crewSuggestions,
        startLat: points.isNotEmpty
            ? points.first.latitude
            : recording.currentPosition?.latitude,
        startLon: points.isNotEmpty
            ? points.first.longitude
            : recording.currentPosition?.longitude,
        endLat: recording.currentPosition?.latitude,
        endLon: recording.currentPosition?.longitude,
      ),
    );

    if (completionData == null) {
      notifier.resume();
      return;
    }

    try {
      await notifier.complete(completionData);
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
      }
    }
  }

  void _centerOnPosition() {
    final position = ref.read(tripRecordingProvider).currentPosition;
    if (position != null) {
      _mapController.move(position, 14);
      setState(() => _followMode = true);
    }
  }

  void _resetPolylineCache() {
    _cachedPolylines.clear();
    _cachedPointCount = 0;
  }

  /// Appends segments for points added since the last build; earlier
  /// segments are reused as-is.
  List<Polyline> _trackPolylines(List<TrackPoint> points) {
    if (points.length < _cachedPointCount) _resetPolylineCache();

    for (var i = _cachedPointCount == 0 ? 1 : _cachedPointCount;
        i < points.length;
        i++) {
      final speed = points[i - 1].speedKnots ?? 0;
      final color = switch (speed) {
        < 3 => AppColors.cyan,
        < 6 => AppColors.green,
        < 12 => AppColors.amber,
        _ => AppColors.red,
      };
      _cachedPolylines.add(
        Polyline(
          points: [
            LatLng(points[i - 1].latitude, points[i - 1].longitude),
            LatLng(points[i].latitude, points[i].longitude),
          ],
          color: color,
          strokeWidth: 3.5,
        ),
      );
    }
    _cachedPointCount = points.length;
    return _cachedPolylines;
  }

  @override
  Widget build(BuildContext context) {
    final recording = ref.watch(tripRecordingProvider);
    final isActive = recording.isActive;
    final saving = recording.status == RecordingStatus.saving;
    final center = recording.currentPosition ?? _defaultCenter;

    // Follow the boat as fixes arrive without rebuilding on every field.
    ref.listen<LatLng?>(
      tripRecordingProvider.select((s) => s.currentPosition),
      (previous, position) {
        if (_followMode && position != null) {
          try {
            _mapController.move(position, _mapController.camera.zoom);
          } catch (_) {}
        }
      },
    );

    final nearbyPorts = _showPorts ? ref.watch(allPortsProvider) : null;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: saving
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
                      if (recording.trackPoints.length >= 2)
                        PolylineLayer(
                          polylines: _trackPolylines(recording.trackPoints),
                        ),
                      if (nearbyPorts case AsyncData(:final value))
                        PortMarkersLayer(
                          ports: value,
                          userPosition: recording.currentPosition,
                        ),
                      if (recording.currentPosition != null)
                        PositionIndicator(
                          position: recording.currentPosition!,
                        ),
                      if (recording.trackPoints.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                recording.trackPoints.first.latitude,
                                recording.trackPoints.first.longitude,
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
                if (isActive)
                  NavigationHud(
                    speedKnots: recording.currentSpeedKnots,
                    heading: recording.currentHeading,
                    distanceNm: recording.totalDistanceNm,
                    startTime: recording.startTime,
                    gpsAccuracy: recording.gpsAccuracy,
                  ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: _GlassIconButton(
                    icon: isActive ? Icons.close : Icons.arrow_back,
                    onPressed:
                        isActive ? _exitWithoutSaving : () => context.pop(),
                    semanticLabel: isActive
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
                    status: switch (recording.status) {
                      RecordingStatus.recording => TripStatus.recording,
                      RecordingStatus.paused => TripStatus.paused,
                      _ => TripStatus.completed,
                    },
                    onStart: _startRecording,
                    onPause: ref.read(tripRecordingProvider.notifier).pause,
                    onResume: () {
                      ref.read(tripRecordingProvider.notifier).resume();
                      setState(() => _followMode = true);
                      HapticFeedback.lightImpact();
                    },
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
