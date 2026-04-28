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
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/features/charts/data/tile_provider.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/recording_controls.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_completion_dialog.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';

class TripRecordingScreen extends ConsumerStatefulWidget {
  const TripRecordingScreen({super.key, required this.boatId});

  final String boatId;

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
  Timer? _elapsedTimer;
  Timer? _uploadTimer;
  Duration _elapsed = Duration.zero;
  Trip? _createdTrip;
  bool _saving = false;
  double? _gpsAccuracy;
  final MapController _mapController = MapController();

  static const _uploadIntervalSeconds = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (state == AppLifecycleState.resumed &&
        _status == TripStatus.recording) {
      _ensureLocationStream();
    }
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
          notificationIcon:
              AndroidResource(name: 'ic_launcher'),
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
    if (_status != TripStatus.recording) return;

    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      speedKnots: DistanceUtils.kmhToKnots(position.speed * 3.6),
    );

    if (_trackPoints.isNotEmpty) {
      final lastPoint = _trackPoints.last;
      final distance = DistanceUtils.calculateDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        point.latitude,
        point.longitude,
      );
      _totalDistance += distance;
    }

    final speedKnots = point.speedKnots ?? 0;
    if (speedKnots > _maxSpeed) {
      _maxSpeed = speedKnots;
    }

    setState(() {
      _trackPoints.add(point);
      _pendingUpload.add(point);
      _gpsAccuracy = position.accuracy;
    });

    _moveMapToPosition(point);
  }

  void _moveMapToPosition(TrackPoint point) {
    try {
      _mapController.move(
        LatLng(point.latitude, point.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    unawaited(HapticFeedback.mediumImpact());

    final hasPermission = await _requestLocationPermission();
    if (!hasPermission) return;

    if (!mounted) return;
    final portController = TextEditingController();
    final departurePort = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Departure Port'),
        content: TextField(
          controller: portController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Port of Barcelona',
            prefixIcon: Icon(Icons.anchor),
          ),
          onSubmitted: (v) =>
              Navigator.of(ctx).pop(v.trim().isEmpty ? null : v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = portController.text.trim();
              Navigator.of(ctx).pop(v.isEmpty ? null : v);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
    portController.dispose();

    if (departurePort == null) return;

    final repo = ref.read(tripRepositoryProvider);
    try {
      final trip = await repo.createTrip(Trip(
        id: '',
        boatId: widget.boatId,
        departurePort: departurePort,
        departureTime: DateTime.now(),
        status: TripStatus.recording,
      ));
      setState(() {
        _createdTrip = trip;
        _status = TripStatus.recording;
        _startTime = DateTime.now();
        _trackPoints.clear();
        _pendingUpload.clear();
        _totalDistance = 0;
        _maxSpeed = 0;
        _elapsed = Duration.zero;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start trip: $e')),
        );
      }
      return;
    }

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == TripStatus.recording && _startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });

    _startLocationStream();

    _uploadTimer = Timer.periodic(
      const Duration(seconds: _uploadIntervalSeconds),
      (_) => _flushPendingPoints(),
    );
  }

  Future<bool> _requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location in Settings'),
          ),
        );
      }
      return false;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable GPS')),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _flushPendingPoints() async {
    if (_pendingUpload.isEmpty || _createdTrip == null) return;

    final batch = List<TrackPoint>.from(_pendingUpload);
    _pendingUpload.clear();

    try {
      final repo = ref.read(tripRepositoryProvider);
      await repo.addTrackPoints(_createdTrip!.id, batch);
    } catch (_) {
      _pendingUpload.insertAll(0, batch);
    }
  }

  void _pauseRecording() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _uploadTimer?.cancel();
    setState(() {
      _status = TripStatus.paused;
    });
  }

  void _resumeRecording() {
    _startLocationStream();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == TripStatus.recording && _startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });
    _uploadTimer = Timer.periodic(
      const Duration(seconds: _uploadIntervalSeconds),
      (_) => _flushPendingPoints(),
    );
    setState(() {
      _status = TripStatus.recording;
    });
  }

  Future<void> _stopRecording() async {
    unawaited(HapticFeedback.heavyImpact());
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _uploadTimer?.cancel();
    setState(() {
      _status = TripStatus.paused;
    });

    if (!mounted) return;
    final result = await showDialog<TripCompletionData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TripCompletionDialog(),
    );

    if (result == null) {
      setState(() => _status = TripStatus.paused);
      return;
    }

    setState(() => _saving = true);

    final repo = ref.read(tripRepositoryProvider);
    try {
      // Flush any remaining pending points.
      if (_pendingUpload.isNotEmpty && _createdTrip != null) {
        await repo.addTrackPoints(_createdTrip!.id, _pendingUpload);
        _pendingUpload.clear();
      }

      if (_createdTrip != null) {
        if (result.crewMembers != null || result.notes != null) {
          await repo.updateTrip(_createdTrip!.copyWith(
            crewMembers: result.crewMembers,
            notes: result.notes,
          ));
        }

        await repo.completeTrip(
          _createdTrip!.id,
          arrivalPort: result.arrivalPort,
          distanceNm: _totalDistance > 0 ? _totalDistance : null,
          engineHours: result.engineHours,
          fuelConsumedL: result.fuelConsumedL,
        );
      }

      ref.invalidate(boatTripsProvider(widget.boatId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip saved')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save trip: $e')),
        );
      }
    }
  }

  String _formatElapsed(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _gpsAccuracyLabel() {
    if (_gpsAccuracy == null) return 'Waiting...';
    if (_gpsAccuracy! <= 5) return 'Excellent';
    if (_gpsAccuracy! <= 15) return 'Good';
    if (_gpsAccuracy! <= 30) return 'Fair';
    return 'Poor';
  }

  Color _gpsAccuracyColor() {
    if (_gpsAccuracy == null) return AppColors.textSecondary;
    if (_gpsAccuracy! <= 5) return AppColors.green;
    if (_gpsAccuracy! <= 15) return AppColors.cyan;
    if (_gpsAccuracy! <= 30) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _status == TripStatus.recording;
    final isPaused = _status == TripStatus.paused;
    final hasStarted = isRecording || isPaused;

    return Scaffold(
      appBar: const NavisAppBar(title: 'Record Trip', showBack: true),
      body: _saving
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving trip...'),
                ],
              ),
            )
          : Column(
              children: [
                if (hasStarted) _buildLiveMap(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (!hasStarted) ...[
                          _buildWeatherCard(),
                          const Spacer(),
                          const Icon(
                            Icons.route,
                            size: 80,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ready to record your trip',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'GPS will track your route, speed, and distance.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(),
                        ],
                        if (hasStarted) ...[
                          _buildGpsIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _formatElapsed(_elapsed),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: AppColors.cyan,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StatColumn(
                                label: 'Distance',
                                value: DistanceUtils.formatDistance(
                                  _totalDistance,
                                ),
                              ),
                              _StatColumn(
                                label: 'Max Speed',
                                value: DistanceUtils.formatSpeed(_maxSpeed),
                              ),
                              _StatColumn(
                                label: 'Points',
                                value: '${_trackPoints.length}',
                              ),
                            ],
                          ),
                          const Spacer(),
                        ],
                        RecordingControls(
                          status: _status,
                          onStart: _startRecording,
                          onPause: _pauseRecording,
                          onResume: _resumeRecording,
                          onStop: _stopRecording,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLiveMap() {
    final points = _trackPoints
        .map((tp) => LatLng(tp.latitude, tp.longitude))
        .toList();

    return RepaintBoundary(
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.isNotEmpty
                ? points.last
                : const LatLng(39.57, 2.63),
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            OpenSeaMapTileProvider.baseLayer,
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: AppColors.cyan,
                    strokeWidth: 3,
                  ),
                ],
              ),
            if (points.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: points.last,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cyan,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.gps_fixed, size: 16, color: _gpsAccuracyColor()),
        const SizedBox(width: 6),
        Text(
          'GPS: ${_gpsAccuracyLabel()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _gpsAccuracyColor(),
                fontWeight: FontWeight.w600,
              ),
        ),
        if (_gpsAccuracy != null) ...[
          const SizedBox(width: 6),
          Text(
            '(±${_gpsAccuracy!.toStringAsFixed(0)}m)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeatherCard() {
    return Consumer(
      builder: (context, ref, _) {
        final weatherAsync = ref.watch(currentWeatherProvider);
        return weatherAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (weather) {
            if (weather == null) return const SizedBox.shrink();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_outlined,
                      color: AppColors.cyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${weather.temperature.toStringAsFixed(0)}\u00b0C'
                        ' \u00b7 Wind ${weather.windSpeed.toStringAsFixed(0)} kt'
                        ' \u00b7 Waves ${weather.waveHeight.toStringAsFixed(1)} m',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
