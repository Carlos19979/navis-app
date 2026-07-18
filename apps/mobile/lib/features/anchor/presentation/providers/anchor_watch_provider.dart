import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:navis_mobile/core/alarm/alarm_service.dart';
import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';

/// One nautical mile in metres — `DistanceUtils.calculateDistance` returns NM.
const double _metersPerNm = 1852.0;

/// Default swing radius: the sector's typical starting point for an anchorage,
/// large enough that normal veering doesn't trip a false alarm.
const double kDefaultAnchorRadiusM = 40;
const double kMinAnchorRadiusM = 15;
const double kMaxAnchorRadiusM = 150;

enum AnchorWatchStatus { idle, armed, dragging }

enum AnchorArmResult { armed, permissionDenied, noFix }

class AnchorWatchState {
  const AnchorWatchState({
    this.status = AnchorWatchStatus.idle,
    this.anchorPosition,
    this.radiusMeters = kDefaultAnchorRadiusM,
    this.currentPosition,
    this.distanceMeters = 0,
    this.maxDistanceMeters = 0,
    this.gpsAccuracy,
    this.alarmSilenced = false,
    this.boatId,
  });

  final AnchorWatchStatus status;
  final LatLng? anchorPosition;
  final double radiusMeters;
  final LatLng? currentPosition;

  /// Live distance from the anchor to the current fix, in metres.
  final double distanceMeters;

  /// Furthest the boat has swung since arming (metres) — a quick sense of how
  /// close to the edge it has been.
  final double maxDistanceMeters;
  final double? gpsAccuracy;

  /// The user silenced the sound while still outside the circle; the banner
  /// stays but the sound won't re-fire until the boat returns inside.
  final bool alarmSilenced;
  final String? boatId;

  bool get isArmed => status != AnchorWatchStatus.idle;
  bool get isDragging => status == AnchorWatchStatus.dragging;

  AnchorWatchState copyWith({
    AnchorWatchStatus? status,
    LatLng? anchorPosition,
    double? radiusMeters,
    LatLng? currentPosition,
    double? distanceMeters,
    double? maxDistanceMeters,
    double? gpsAccuracy,
    bool? alarmSilenced,
    String? boatId,
  }) {
    return AnchorWatchState(
      status: status ?? this.status,
      anchorPosition: anchorPosition ?? this.anchorPosition,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      currentPosition: currentPosition ?? this.currentPosition,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      maxDistanceMeters: maxDistanceMeters ?? this.maxDistanceMeters,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      alarmSilenced: alarmSilenced ?? this.alarmSilenced,
      boatId: boatId ?? this.boatId,
    );
  }

  static const AnchorWatchState initial = AnchorWatchState();
}

/// Owns the anchor-watch lifecycle: a background-capable GPS stream that fires
/// a loud alarm when the boat drifts beyond the swing radius. NOT autoDispose —
/// the watch must survive navigating away from the anchor screen.
final anchorWatchProvider =
    StateNotifierProvider<AnchorWatchNotifier, AnchorWatchState>((ref) {
  return AnchorWatchNotifier(ref);
});

class AnchorWatchNotifier extends StateNotifier<AnchorWatchState> {
  AnchorWatchNotifier(this._ref) : super(AnchorWatchState.initial);

  final Ref _ref;
  StreamSubscription<Position>? _sub;

  /// Consecutive out-of-circle fixes before we declare a drag — smooths over
  /// single-fix GPS spikes that the sector reports as a false-alarm source.
  int _consecutiveOut = 0;
  static const _outThreshold = 2;

  LocalDatabase get _db => _ref.read(localDatabaseProvider);
  AlarmService get _alarm => _ref.read(alarmServiceProvider);

  /// Drops the anchor at the current position and arms the watch. Captures a
  /// one-shot fix for a stable anchor point, requests background location +
  /// notification permission, persists, then starts the live stream.
  Future<AnchorArmResult> dropAnchor({
    String? boatId,
    double? radiusMeters,
  }) async {
    final permission = await _ensurePermission();
    if (permission == null) return AnchorArmResult.permissionDenied;

    LatLng anchor;
    try {
      final fix = await Geolocator.getCurrentPosition();
      anchor = LatLng(fix.latitude, fix.longitude);
    } catch (_) {
      final last = state.currentPosition;
      if (last == null) return AnchorArmResult.noFix;
      anchor = last;
    }

    final radius = radiusMeters ?? state.radiusMeters;
    final setAt = DateTime.now();
    _consecutiveOut = 0;
    state = AnchorWatchState(
      status: AnchorWatchStatus.armed,
      anchorPosition: anchor,
      radiusMeters: radius,
      currentPosition: anchor,
      boatId: boatId,
    );

    await _db.startAnchorWatch(
      boatId: boatId,
      anchorLat: anchor.latitude,
      anchorLon: anchor.longitude,
      radiusM: radius,
      setAt: setAt,
    );
    // Start monitoring immediately. The notification permission is requested in
    // the background — the watch must NOT block on a permission dialog (which
    // can hang), or it would arm without ever receiving GPS fixes.
    _startStream();
    unawaited(_alarm.requestPermission());
    return AnchorArmResult.armed;
  }

  /// Adjusts the swing radius on an armed watch (persisted, re-evaluated on the
  /// next fix). Clamped to the supported range.
  void adjustRadius(double radiusMeters) {
    final r = radiusMeters.clamp(kMinAnchorRadiusM, kMaxAnchorRadiusM);
    state = state.copyWith(radiusMeters: r);
    if (state.isArmed) {
      unawaited(_db.updateAnchorWatch({'radius_m': r}));
    }
  }

  /// Re-drops the anchor at the current position (recenters the circle) — the
  /// usual response to a drag that turns out to be a new, safe resting spot.
  Future<void> recenter() async {
    final pos = state.currentPosition;
    if (pos == null || !state.isArmed) return;
    _consecutiveOut = 0;
    await _alarm.stop();
    state = state.copyWith(
      status: AnchorWatchStatus.armed,
      anchorPosition: pos,
      distanceMeters: 0,
      maxDistanceMeters: 0,
      alarmSilenced: false,
    );
    await _db.updateAnchorWatch({
      'anchor_lat': pos.latitude,
      'anchor_lon': pos.longitude,
    });
  }

  /// Silences the sound while the boat is still adrift; the banner stays and
  /// the sound re-arms once the boat returns inside the circle.
  Future<void> silenceAlarm() async {
    await _alarm.stop();
    state = state.copyWith(alarmSilenced: true);
  }

  /// Fully stops the watch and clears persistence.
  Future<void> disarm() async {
    await _sub?.cancel();
    _sub = null;
    _consecutiveOut = 0;
    await _alarm.stop();
    await _db.clearAnchorWatch();
    state = AnchorWatchState.initial;
  }

  /// Restores an armed watch after an app relaunch (mirrors the trip-recording
  /// recover flow). Returns true when a watch was restored.
  Future<bool> recoverWatch() async {
    if (state.isArmed) return true;
    Map<String, dynamic>? row;
    try {
      row = await _db.getAnchorWatch();
    } catch (_) {
      return false;
    }
    if (row == null) return false;
    if (await _ensurePermission() == null) return false;

    final anchor = LatLng(
      row['anchor_lat'] as double,
      row['anchor_lon'] as double,
    );
    _consecutiveOut = 0;
    state = AnchorWatchState(
      status: AnchorWatchStatus.armed,
      anchorPosition: anchor,
      radiusMeters: (row['radius_m'] as num).toDouble(),
      currentPosition: anchor,
      boatId: row['boat_id'] as String?,
    );
    _startStream();
    return true;
  }

  /// Whether a persisted watch exists without loading it. Never throws.
  Future<bool> hasPersistedWatch() async {
    if (state.isArmed) return false;
    try {
      return await _db.getAnchorWatch() != null;
    } catch (_) {
      return false;
    }
  }

  /// Re-arms the GPS stream if the OS killed it while backgrounded.
  void ensureStream() {
    if (!state.isArmed) return;
    if (_sub != null) return;
    _startStream();
  }

  // ── GPS ─────────────────────────────────────────────────────────────────

  Future<LocationPermission?> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return permission;
  }

  void _startStream() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen(_onFix);
  }

  /// Anchor-watch location settings — distinct from trip recording so we can
  /// opt into true background updates without changing recording behaviour. A
  /// tight distanceFilter (2 m) makes the drift check responsive.
  LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Navis anchor watch is active',
          notificationText: 'Monitoring your position',
          notificationIcon: AndroidResource(name: 'ic_launcher'),
        ),
      );
    }
    if (Platform.isIOS) {
      // geolocator's AppleSettings already defaults allowBackgroundLocation
      // Updates=true and pauseLocationUpdatesAutomatically=false, which is
      // exactly what an anchor watch needs; only the background indicator is
      // opted into here.
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
        activityType: ActivityType.otherNavigation,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );
  }

  void _onFix(Position position) {
    // A GPS fix can arrive after the notifier is disposed (the stream is
    // cancelled asynchronously, and the OS/fake stream may deliver one more
    // tick during teardown) — touching `state` then throws. Guard it.
    if (!mounted) return;
    final pos = LatLng(position.latitude, position.longitude);
    final anchor = state.anchorPosition;
    if (anchor == null) {
      state =
          state.copyWith(currentPosition: pos, gpsAccuracy: position.accuracy);
      return;
    }

    final distance = DistanceUtils.calculateDistance(
          anchor.latitude,
          anchor.longitude,
          pos.latitude,
          pos.longitude,
        ) *
        _metersPerNm;
    final maxDistance =
        distance > state.maxDistanceMeters ? distance : state.maxDistanceMeters;

    // Too-imprecise fixes can't be trusted to declare a drag: update the
    // readout but don't count them toward the out-threshold.
    final accuracy = position.accuracy;
    final trustworthy = accuracy <= state.radiusMeters;
    final outside = distance > state.radiusMeters;

    if (outside && trustworthy) {
      _consecutiveOut++;
    } else if (!outside) {
      _consecutiveOut = 0;
    }

    final dragging = _consecutiveOut >= _outThreshold;

    if (dragging) {
      state = state.copyWith(
        status: AnchorWatchStatus.dragging,
        currentPosition: pos,
        distanceMeters: distance,
        maxDistanceMeters: maxDistance,
        gpsAccuracy: accuracy,
      );
      if (!state.alarmSilenced) {
        unawaited(_alarm.trigger(
          title: 'Anchor drag alarm',
          body: 'Your boat has drifted outside the anchor circle.',
        ));
      }
    } else {
      // Back inside (or not yet confirmed out): clear any silence + alarm.
      if (state.status == AnchorWatchStatus.dragging || state.alarmSilenced) {
        unawaited(_alarm.stop());
      }
      state = state.copyWith(
        status: AnchorWatchStatus.armed,
        currentPosition: pos,
        distanceMeters: distance,
        maxDistanceMeters: maxDistance,
        gpsAccuracy: accuracy,
        alarmSilenced: false,
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
