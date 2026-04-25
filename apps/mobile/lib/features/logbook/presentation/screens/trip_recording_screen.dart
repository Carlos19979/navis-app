import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/recording_controls.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';

class TripRecordingScreen extends ConsumerStatefulWidget {
  const TripRecordingScreen({super.key});

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

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _status = TripStatus.recording;
      _startTime = DateTime.now();
      _trackPoints.clear();
      _totalDistance = 0;
      _maxSpeed = 0;
      _elapsed = Duration.zero;
    });

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
        speedKnots:
            DistanceUtils.kmhToKnots(position.speed * 3.6),
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

  void _stopRecording() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    setState(() {
      _status = TripStatus.completed;
    });

    if (mounted) {
      context.pop();
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
