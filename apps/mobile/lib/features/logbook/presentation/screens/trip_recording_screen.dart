import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
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

class _TripRecordingScreenState extends ConsumerState<TripRecordingScreen> {
  TripStatus _status = TripStatus.completed;
  final List<TrackPoint> _trackPoints = [];
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _startTime;
  double _totalDistance = 0;
  double _maxSpeed = 0;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  Trip? _createdTrip;
  bool _saving = false;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    unawaited(HapticFeedback.mediumImpact());
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

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
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
      });
    });
  }

  void _pauseRecording() {
    _positionSubscription?.pause();
    _elapsedTimer?.cancel();
    setState(() {
      _status = TripStatus.paused;
    });
  }

  void _resumeRecording() {
    _positionSubscription?.resume();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_status == TripStatus.recording && _startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });
    setState(() {
      _status = TripStatus.recording;
    });
  }

  Future<void> _stopRecording() async {
    unawaited(HapticFeedback.heavyImpact());
    await _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
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
      if (_trackPoints.isNotEmpty && _createdTrip != null) {
        await repo.addTrackPoints(_createdTrip!.id, _trackPoints);
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
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (!hasStarted)
                    Consumer(
                      builder: (context, ref, _) {
                        final weatherAsync =
                            ref.watch(currentWeatherProvider);
                        return weatherAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (weather) {
                            if (weather == null) {
                              return const SizedBox.shrink();
                            }
                            return Card(
                              margin:
                                  const EdgeInsets.only(bottom: 16),
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  const Spacer(),
                  if (hasStarted) ...[
                    Text(
                      _formatElapsed(_elapsed),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatColumn(
                          label: 'Distance',
                          value: DistanceUtils.formatDistance(_totalDistance),
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
                  ] else ...[
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
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
