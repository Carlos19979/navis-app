import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_completion_dialog.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';

/// Outcome of asking to start a recording, so the screen can react (snackbars
/// need a BuildContext the notifier must not hold).
enum RecordingStartResult { started, permissionDenied, permissionDeniedForever }

/// Recording lifecycle. `idle` before start and after discard/save.
enum RecordingStatus { idle, recording, paused, saving }

class TripRecordingState {
  const TripRecordingState({
    this.status = RecordingStatus.idle,
    this.trackPoints = const [],
    this.startTime,
    this.totalDistanceNm = 0,
    this.maxSpeedKnots = 0,
    this.currentSpeedKnots = 0,
    this.currentHeading,
    this.gpsAccuracy,
    this.currentPosition,
    this.trip,
    this.boatId,
    this.isRegatta = false,
  });

  final RecordingStatus status;
  final List<TrackPoint> trackPoints;
  final DateTime? startTime;
  final double totalDistanceNm;
  final double maxSpeedKnots;
  final double currentSpeedKnots;
  final double? currentHeading;
  final double? gpsAccuracy;
  final LatLng? currentPosition;

  /// Server-side trip once created (immediately for regattas, best-effort at
  /// start for solo trips, retried at completion).
  final Trip? trip;
  final String? boatId;
  final bool isRegatta;

  bool get isActive =>
      status == RecordingStatus.recording || status == RecordingStatus.paused;

  double? get avgSpeedKnots {
    final start = startTime;
    if (start == null) return null;
    final seconds = DateTime.now().difference(start).inSeconds;
    return seconds > 0 ? totalDistanceNm / (seconds / 3600) : null;
  }

  TripRecordingState copyWith({
    RecordingStatus? status,
    List<TrackPoint>? trackPoints,
    DateTime? startTime,
    double? totalDistanceNm,
    double? maxSpeedKnots,
    double? currentSpeedKnots,
    double? currentHeading,
    double? gpsAccuracy,
    LatLng? currentPosition,
    Trip? trip,
    String? boatId,
    bool? isRegatta,
  }) {
    return TripRecordingState(
      status: status ?? this.status,
      trackPoints: trackPoints ?? this.trackPoints,
      startTime: startTime ?? this.startTime,
      totalDistanceNm: totalDistanceNm ?? this.totalDistanceNm,
      maxSpeedKnots: maxSpeedKnots ?? this.maxSpeedKnots,
      currentSpeedKnots: currentSpeedKnots ?? this.currentSpeedKnots,
      currentHeading: currentHeading ?? this.currentHeading,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      currentPosition: currentPosition ?? this.currentPosition,
      trip: trip ?? this.trip,
      boatId: boatId ?? this.boatId,
      isRegatta: isRegatta ?? this.isRegatta,
    );
  }

  /// copyWith cannot null out `trip`; used when a recording is fully reset.
  static const TripRecordingState initial = TripRecordingState();
}

/// Owns the GPS recording lifecycle: location stream, per-fix persistence to
/// sqlite (crash-safe), periodic batched upload (falling back to the offline
/// mutation queue), stats, and completion/discard.
///
/// NOT autoDispose: the recording must survive navigation away from the map.
final tripRecordingProvider =
    StateNotifierProvider<TripRecordingNotifier, TripRecordingState>((ref) {
  return TripRecordingNotifier(ref);
});

class TripRecordingNotifier extends StateNotifier<TripRecordingState> {
  TripRecordingNotifier(this._ref) : super(TripRecordingState.initial);

  final Ref _ref;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _uploadTimer;

  static const _uploadInterval = Duration(seconds: 60);

  LocalDatabase get _db => _ref.read(localDatabaseProvider);

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Requests permission and starts recording. For regatta trips [tripId] is
  /// the already-started server trip; solo trips are created best-effort.
  Future<RecordingStartResult> start({
    required String boatId,
    String? tripId,
    bool isRegatta = false,
    String? departurePort,
  }) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return RecordingStartResult.permissionDenied;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return RecordingStartResult.permissionDeniedForever;
    }

    // Seed the position so the departure-port lookup has something to work
    // with before the first live fix arrives.
    var seedPosition = state.currentPosition;
    if (seedPosition == null) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          seedPosition = LatLng(last.latitude, last.longitude);
        }
      } catch (_) {}
    }

    final startTime = DateTime.now();
    state = TripRecordingState(
      status: RecordingStatus.recording,
      startTime: startTime,
      boatId: boatId,
      isRegatta: isRegatta,
      currentPosition: seedPosition,
      trip: tripId != null
          ? Trip(
              id: tripId,
              boatId: boatId,
              departurePort: departurePort ?? '',
              departureTime: startTime,
              status: TripStatus.recording,
            )
          : null,
    );

    await _db.startRecordingSession(
      boatId: boatId,
      tripId: tripId,
      isRegatta: isRegatta,
      departurePort: departurePort,
      startedAt: startTime,
    );

    _startLocationStream();
    _uploadTimer = Timer.periodic(_uploadInterval, (_) => uploadPending());

    if (tripId == null) {
      await _createServerTrip(departurePort);
    }
    return RecordingStartResult.started;
  }

  /// Restores a crash-interrupted session from sqlite. Returns true when a
  /// session was restored (state is then recording/paused with the persisted
  /// points and recomputed stats).
  Future<bool> recoverSession() async {
    if (state.isActive) return true;
    final session = await _db.getRecordingSession();
    if (session == null) return false;

    final rows = await _db.getRecordingPoints();
    final points = rows
        .map((r) => TrackPoint(
              latitude: r['lat'] as double,
              longitude: r['lon'] as double,
              timestamp: DateTime.parse(r['timestamp'] as String),
              speedKnots: r['speed_knots'] as double?,
            ))
        .toList();

    var distance = 0.0;
    var maxSpeed = 0.0;
    for (var i = 1; i < points.length; i++) {
      distance += DistanceUtils.calculateDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    for (final p in points) {
      if ((p.speedKnots ?? 0) > maxSpeed) maxSpeed = p.speedKnots!;
    }

    final tripId = session['trip_id'] as String?;
    final boatId = session['boat_id'] as String;
    final startedAt = DateTime.parse(session['started_at'] as String);
    final paused = session['status'] == 'paused';

    state = TripRecordingState(
      status: paused ? RecordingStatus.paused : RecordingStatus.recording,
      trackPoints: points,
      startTime: startedAt,
      totalDistanceNm: distance,
      maxSpeedKnots: maxSpeed,
      boatId: boatId,
      isRegatta: (session['is_regatta'] as int) == 1,
      currentPosition: points.isNotEmpty
          ? LatLng(points.last.latitude, points.last.longitude)
          : null,
      trip: tripId != null
          ? Trip(
              id: tripId,
              boatId: boatId,
              departurePort: (session['departure_port'] as String?) ?? '',
              departureTime: startedAt,
              status: TripStatus.recording,
            )
          : null,
    );

    if (!paused) _startLocationStream();
    _uploadTimer ??= Timer.periodic(_uploadInterval, (_) => uploadPending());
    return true;
  }

  /// Whether a persisted session exists without loading it (for the resume
  /// prompt on app open). Never throws — a broken local DB must not take the
  /// dashboard down.
  Future<bool> hasPersistedSession() async {
    if (state.isActive) return false;
    try {
      return await _db.getRecordingSession() != null;
    } catch (_) {
      return false;
    }
  }

  void pause() {
    if (state.status != RecordingStatus.recording) return;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    state = state.copyWith(status: RecordingStatus.paused);
    unawaited(_db.updateRecordingSession({'status': 'paused'}));
  }

  void resume() {
    if (state.status != RecordingStatus.paused) return;
    state = state.copyWith(status: RecordingStatus.recording);
    unawaited(_db.updateRecordingSession({'status': 'recording'}));
    _startLocationStream();
  }

  /// Re-arms the GPS stream if the OS killed it (app resumed from background).
  void ensureLocationStream() {
    if (state.status != RecordingStatus.recording) return;
    if (_positionSubscription != null) return;
    _startLocationStream();
  }

  /// Discards the recording: deletes the solo trip on the server (or reverts
  /// a regatta to planned) and clears all local state.
  Future<void> discard() async {
    _stopStreamAndTimers();
    final trip = state.trip;
    final isRegatta = state.isRegatta;
    try {
      if (trip != null) {
        if (isRegatta) {
          await _ref.read(regattaRepositoryProvider).revertToPlanned(trip.id);
          _ref.invalidate(regattaProvider(trip.id));
        } else {
          await _ref.read(tripRepositoryProvider).deleteTrip(trip.id);
        }
      }
    } catch (_) {
      // Best effort — an unreachable server must not trap the user here.
    }
    await _db.clearRecordingSession();
    state = TripRecordingState.initial;
  }

  /// Completes the trip: flushes remaining points, then completes (or creates
  /// with full track) on the server. Falls back to the offline mutation queue
  /// so finishing a trip works without connectivity. Throws on hard failure.
  Future<void> complete(TripCompletionData data) async {
    _stopStreamAndTimers();
    state = state.copyWith(status: RecordingStatus.saving);

    final repo = _ref.read(tripRepositoryProvider);
    final queue = _ref.read(mutationQueueProvider.notifier);
    final trip = state.trip;

    try {
      if (trip != null) {
        await uploadPending();

        if (data.departurePort != null &&
            data.departurePort != trip.departurePort) {
          try {
            await repo.updateTrip(trip.copyWith(
              departurePort: data.departurePort,
            ));
          } catch (_) {
            await queue.enqueue(
              method: 'PUT',
              path: '/api/v1/trips/${trip.id}',
              body: {'departure_port': data.departurePort},
            );
          }
        }

        final completeBody = <String, dynamic>{
          if (data.arrivalPort != null) 'arrival_port': data.arrivalPort,
          'distance_nm': state.totalDistanceNm,
          if (data.engineHours != null) 'engine_hours': data.engineHours,
          if (data.fuelConsumedL != null) 'fuel_consumed_l': data.fuelConsumedL,
        };
        try {
          await repo.completeTrip(
            trip.id,
            arrivalPort: data.arrivalPort,
            distanceNm: state.totalDistanceNm,
            engineHours: data.engineHours,
            fuelConsumedL: data.fuelConsumedL,
          );
        } catch (_) {
          // Offline: the queue replays the completion when back online.
          await queue.enqueue(
            method: 'PUT',
            path: '/api/v1/trips/${trip.id}/complete',
            body: completeBody,
          );
        }
      } else {
        // Solo trip whose creation failed at start (offline start): create it
        // now with the full track in one call.
        final created = await repo.createTrip(Trip(
          id: '',
          boatId: state.boatId!,
          departurePort: data.departurePort ?? 'Unknown',
          departureTime: state.startTime!,
          arrivalPort: data.arrivalPort,
          arrivalTime: DateTime.now(),
          distanceNm: state.totalDistanceNm,
          maxSpeedKnots: state.maxSpeedKnots,
          avgSpeedKnots: state.avgSpeedKnots,
          notes: data.notes,
          engineHours: data.engineHours,
          fuelConsumedL: data.fuelConsumedL,
          crewMembers: data.crewMembers,
          trackPoints: state.trackPoints,
        ));
        if (state.trackPoints.isNotEmpty) {
          try {
            await repo.addTrackPoints(created.id, state.trackPoints);
          } catch (_) {
            await queue.enqueue(
              method: 'POST',
              path: '/api/v1/trips/${created.id}/tracks',
              body: {'points': _pointsJson(state.trackPoints)},
            );
          }
        }
      }

      final finishedBoatId = state.boatId;
      final finishedTrip = state.trip;
      await _db.clearRecordingSession();
      state = TripRecordingState.initial;

      if (finishedBoatId != null) {
        _ref.invalidate(boatTripsProvider(finishedBoatId));
      }
      if (finishedTrip != null) {
        _ref.invalidate(regattaProvider(finishedTrip.id));
      }
    } catch (e) {
      // Hard failure (e.g. creating the trip offline with no queue path):
      // stay in saving-failed state so the user can retry; keep the session.
      state = state.copyWith(status: RecordingStatus.paused);
      rethrow;
    }
  }

  // ── GPS stream ──────────────────────────────────────────────────────────

  void _startLocationStream() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _platformLocationSettings(),
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

    if (state.status != RecordingStatus.recording) {
      state = state.copyWith(
        currentPosition: newPos,
        gpsAccuracy: position.accuracy,
        currentSpeedKnots: speedKn,
        currentHeading:
            position.heading >= 0 ? position.heading : state.currentHeading,
      );
      return;
    }

    final point = TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      speedKnots: speedKn,
    );

    var distance = state.totalDistanceNm;
    if (state.trackPoints.isNotEmpty) {
      final last = state.trackPoints.last;
      distance += DistanceUtils.calculateDistance(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
    }

    state = state.copyWith(
      currentPosition: newPos,
      gpsAccuracy: position.accuracy,
      currentSpeedKnots: speedKn,
      currentHeading:
          position.heading >= 0 ? position.heading : state.currentHeading,
      totalDistanceNm: distance,
      maxSpeedKnots:
          speedKn > state.maxSpeedKnots ? speedKn : state.maxSpeedKnots,
      trackPoints: [...state.trackPoints, point],
    );

    // Crash safety: every fix hits disk as it arrives.
    unawaited(_persistPoint(point));
  }

  Future<void> _persistPoint(TrackPoint point) async {
    try {
      await _db.insertRecordingPoint(
        lat: point.latitude,
        lon: point.longitude,
        timestamp: point.timestamp,
        speedKnots: point.speedKnots,
      );
    } catch (_) {
      // Persistence is a safety net; never break the recording over it.
    }
  }

  // ── Upload ──────────────────────────────────────────────────────────────

  /// Uploads not-yet-handed-off points. Direct POST first; on failure the
  /// batch goes to the offline mutation queue (exactly-once handoff, marked
  /// in sqlite either way).
  Future<void> uploadPending() async {
    final trip = state.trip;
    if (trip == null) return;

    final rows = await _db.getPendingRecordingPoints();
    if (rows.isEmpty) return;

    final maxSeq = rows.last['seq'] as int;
    final points = rows
        .map((r) => TrackPoint(
              latitude: r['lat'] as double,
              longitude: r['lon'] as double,
              timestamp: DateTime.parse(r['timestamp'] as String),
              speedKnots: r['speed_knots'] as double?,
            ))
        .toList();

    try {
      await _ref.read(tripRepositoryProvider).addTrackPoints(trip.id, points);
    } catch (_) {
      await _ref.read(mutationQueueProvider.notifier).enqueue(
        method: 'POST',
        path: '/api/v1/trips/${trip.id}/tracks',
        body: {'points': _pointsJson(points)},
      );
    }
    await _db.markRecordingPointsHandedOff(maxSeq);
  }

  Future<void> _createServerTrip(String? departurePort) async {
    try {
      final repo = _ref.read(tripRepositoryProvider);
      // Prefer the port chosen up front, then the nearest port, then the
      // boat's home port, before leaving it "Unknown".
      var departureName = (departurePort != null && departurePort.isNotEmpty)
          ? departurePort
          : 'Unknown';

      final position = state.currentPosition;
      if (departureName == 'Unknown' && position != null) {
        try {
          final ports = await _ref.read(portRepositoryProvider).getNearby(
                lat: position.latitude,
                lon: position.longitude,
                limit: 1,
              );
          if (ports.isNotEmpty) departureName = ports.first.name;
        } catch (_) {}
      }
      if (departureName == 'Unknown') {
        final boats = _ref.read(boatsProvider).valueOrNull ?? const [];
        for (final b in boats) {
          if (b.id == state.boatId &&
              b.homePort != null &&
              b.homePort!.isNotEmpty) {
            departureName = b.homePort!;
            break;
          }
        }
      }

      final trip = await repo.createTrip(Trip(
        id: '',
        boatId: state.boatId!,
        departurePort: departureName,
        departureTime: state.startTime!,
        status: TripStatus.recording,
      ));
      state = state.copyWith(trip: trip);
      await _db.updateRecordingSession({
        'trip_id': trip.id,
        'departure_port': departureName,
      });
    } catch (_) {
      // Offline start: the trip (with full track) is created at completion.
    }
  }

  List<Map<String, dynamic>> _pointsJson(List<TrackPoint> points) => points
      .map((p) => {
            'lat': p.latitude,
            'lon': p.longitude,
            'recorded_at': p.timestamp.toUtc().toIso8601String(),
            if (p.speedKnots != null) 'speed_knots': p.speedKnots,
          })
      .toList();

  void _stopStreamAndTimers() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  @override
  void dispose() {
    _stopStreamAndTimers();
    super.dispose();
  }
}
