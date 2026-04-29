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
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

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
    if (state == AppLifecycleState.resumed && _status == TripStatus.recording) {
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
    if (_status != TripStatus.recording) return;

    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      speedKnots: position.speed * 1.94384,
    );

    setState(() {
      _gpsAccuracy = position.accuracy;

      if (_trackPoints.isNotEmpty) {
        final last = _trackPoints.last;
        _totalDistance += DistanceUtils.calculateDistance(
          last.latitude,
          last.longitude,
          point.latitude,
          point.longitude,
        );
      }

      final speedKn = point.speedKnots ?? 0;
      if (speedKn > _maxSpeed) _maxSpeed = speedKn;

      _trackPoints.add(point);
      _pendingUpload.add(point);
    });

    try {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to record trips',
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
          const SnackBar(
            content: Text(
              'Location permission permanently denied. '
              'Enable in settings.',
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
      _elapsed = Duration.zero;
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

    try {
      final repo = ref.read(tripRepositoryProvider);
      final trip = await repo.createTrip(Trip(
        id: '',
        boatId: widget.boatId,
        departurePort: 'Recording...',
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
    setState(() => _status = TripStatus.recording);
    _startLocationStream();
    HapticFeedback.lightImpact();
  }

  Future<void> _stopRecording() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _elapsedTimer?.cancel();
    _uploadTimer?.cancel();

    unawaited(HapticFeedback.heavyImpact());

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
      ),
    );

    if (completionData == null) {
      if (_status != TripStatus.completed) {
        _startLocationStream();
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
      }
      return;
    }

    setState(() {
      _status = TripStatus.completed;
      _saving = true;
    });

    try {
      final repo = ref.read(tripRepositoryProvider);

      if (_createdTrip != null) {
        final updated = _createdTrip!.copyWith(
          departurePort: completionData.arrivalPort ?? 'Unknown',
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
          status: TripStatus.completed,
          trackPoints: _trackPoints,
        );
        await repo.updateTrip(updated);
        if (_pendingUpload.isNotEmpty) {
          await repo.addTrackPoints(
            _createdTrip!.id,
            _pendingUpload,
          );
        }
      } else {
        final trip = await repo.createTrip(Trip(
          id: '',
          boatId: widget.boatId,
          departurePort: completionData.arrivalPort ?? 'Unknown',
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip saved!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save trip: $e'),
          ),
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
      await repo.addTrackPoints(
        _createdTrip!.id,
        toUpload,
      );
    } catch (e) {
      _pendingUpload.insertAll(0, toUpload);
      debugPrint('Failed to upload track points: $e');
    }
  }

  Color _gpsAccuracyColor() {
    if (_gpsAccuracy == null) return AppColors.textSecondary;
    if (_gpsAccuracy! < 10) return AppColors.green;
    if (_gpsAccuracy! < 25) return AppColors.amber;
    return AppColors.red;
  }

  String _gpsAccuracyLabel() {
    if (_gpsAccuracy == null) return 'Waiting...';
    if (_gpsAccuracy! < 10) return 'Excellent';
    if (_gpsAccuracy! < 25) return 'Good';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: switch (_status) {
            TripStatus.recording => 'Recording Trip',
            TripStatus.paused => 'Paused',
            TripStatus.completed => 'New Trip',
          },
          showBack: true,
        ),
        body: _saving
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.cyan,
                    ),
                    SizedBox(height: 16),
                    Text('Saving trip...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMap(),
                    const SizedBox(height: 12),
                    if (_status != TripStatus.completed) _buildGpsIndicator(),
                    const SizedBox(height: 16),
                    if (_status != TripStatus.completed) ...[
                      _buildStatsRow(),
                      const SizedBox(height: 12),
                      _buildWeatherCard(),
                      const SizedBox(height: 24),
                    ],
                    RecordingControls(
                      status: _status,
                      onStart: _startRecording,
                      onPause: _pauseRecording,
                      onResume: _resumeRecording,
                      onStop: _stopRecording,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMap() {
    final points =
        _trackPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.glassBorder,
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(39.57, 2.63),
                initialZoom: 14,
                interactionOptions: InteractionOptions(
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
                            gradient: AppColors.cyanGradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
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
        ),
      ),
    );
  }

  Widget _buildGpsIndicator() {
    final color = _gpsAccuracyColor();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gps_fixed, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            'GPS: ${_gpsAccuracyLabel()}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (_gpsAccuracy != null) ...[
            const SizedBox(width: 6),
            Text(
              '(\u00b1${_gpsAccuracy!.toStringAsFixed(0)}m)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final avgSpeed = _elapsed.inSeconds > 0
        ? _totalDistance / (_elapsed.inSeconds / 3600)
        : 0.0;
    final hours = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;

    return NavisCard(
      child: Row(
        children: [
          Expanded(
            child: _HeroStat(
              label: 'Distance',
              value: _totalDistance.toStringAsFixed(2),
              unit: 'NM',
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: AppColors.glassBorder,
          ),
          Expanded(
            child: _HeroStat(
              label: 'Speed',
              value: avgSpeed.toStringAsFixed(1),
              unit: 'kn',
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: AppColors.glassBorder,
          ),
          Expanded(
            child: _HeroStat(
              label: 'Time',
              value:
                  '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              unit: '',
            ),
          ),
        ],
      ),
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
            return NavisCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.glassWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_outlined,
                      color: AppColors.cyan,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${weather.temperature.toStringAsFixed(0)}\u00b0C'
                      ' \u00b7 Wind ${weather.windSpeed.toStringAsFixed(0)} kt'
                      ' \u00b7 Waves ${weather.waveHeight.toStringAsFixed(1)} m',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyan,
                    ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
