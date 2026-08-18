import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:navis_mobile/core/alarm/alarm_service.dart';
import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/lifecycle/gps_stream_watchdog.dart';
import 'package:navis_mobile/features/anchor/presentation/providers/anchor_watch_provider.dart';

import '../../helpers/lifecycle.dart';
import '../../helpers/local_db.dart';

class MockAlarmService extends Mock implements AlarmService {}

/// Controllable GPS: drives a stream we feed by hand and a settable one-shot
/// fix, so the anchor-watch drift logic runs without touching native location.
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  final _controller = StreamController<Position>.broadcast();
  LatLng current = const LatLng(39.5, 2.6);
  LocationPermission permission = LocationPermission.always;

  Position _pos(LatLng at, double accuracy) => Position(
        latitude: at.latitude,
        longitude: at.longitude,
        timestamp: DateTime.now(),
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      _pos(current, 5);

  @override
  Future<Position?> getLastKnownPosition(
          {bool forceLocationManager = false}) async =>
      _pos(current, 5);

  /// How many times the notifier subscribed — the evidence that a dead
  /// background stream was re-armed.
  int streamStarts = 0;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamStarts++;
    return _controller.stream;
  }

  void emit(LatLng at, {double accuracy = 5}) =>
      _controller.add(_pos(at, accuracy));

  Future<void> close() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late MockAlarmService alarm;
  late FakeGeolocatorPlatform gps;
  late ProviderContainer container;
  late FakeLifecycle lifecycle;

  /// What the GPS watchdog reads as "now", so a stream can be aged without
  /// waiting ninety seconds.
  late DateTime gpsNow;

  // Anchor at Palma; ~44 m north is outside a 40 m circle, ~5.5 m north inside.
  const anchor = LatLng(39.5, 2.6);
  const outside = LatLng(39.5004, 2.6);
  const inside = LatLng(39.50005, 2.6);

  setUpAll(() async {
    await useIsolatedDatabase('anchor_watch');
  });

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, 'navis_cache.db'));

    gps = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = gps;

    db = LocalDatabase();
    alarm = MockAlarmService();
    when(() => alarm.requestPermission()).thenAnswer((_) async {});
    when(() => alarm.stop()).thenAnswer((_) async {});
    when(() => alarm.trigger(
          title: any(named: 'title'),
          body: any(named: 'body'),
        )).thenAnswer((_) async {});

    lifecycle = FakeLifecycle();
    gpsNow = DateTime(2026, 8, 18, 10);
    container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWithValue(db),
      alarmServiceProvider.overrideWithValue(alarm),
      ...lifecycle.overrides,
      gpsWatchdogClockProvider.overrideWithValue(() => gpsNow),
    ]);
  });

  tearDown(() async {
    container.dispose();
    lifecycle.dispose();
    await gps.close();
    await db.close();
  });

  /// Emits a fix and lets the notifier's stream listener run.
  Future<void> emit(LatLng at, {double accuracy = 5}) async {
    gps.emit(at, accuracy: accuracy);
    await pumpEventQueue();
  }

  test('dropAnchor arms the watch and persists it', () async {
    gps.current = anchor;
    final notifier = container.read(anchorWatchProvider.notifier);

    final result = await notifier.dropAnchor(boatId: 'boat-1');

    expect(result, AnchorArmResult.armed);
    final state = container.read(anchorWatchProvider);
    expect(state.status, AnchorWatchStatus.armed);
    expect(state.anchorPosition, anchor);
    expect(await notifier.hasPersistedWatch(), isFalse); // isArmed → false
    expect(await db.getAnchorWatch(), isNotNull);
    verify(() => alarm.requestPermission()).called(1);
  });

  test('dropAnchor without permission returns permissionDenied', () async {
    gps.permission = LocationPermission.denied;
    final notifier = container.read(anchorWatchProvider.notifier);

    expect(await notifier.dropAnchor(), AnchorArmResult.permissionDenied);
    expect(container.read(anchorWatchProvider).status, AnchorWatchStatus.idle);
  });

  test('two out-of-circle fixes trigger the drag alarm', () async {
    gps.current = anchor;
    final notifier = container.read(anchorWatchProvider.notifier);
    await notifier.dropAnchor(boatId: 'boat-1');

    await emit(inside);
    expect(container.read(anchorWatchProvider).status,
        AnchorWatchStatus.armed); // still inside
    verifyNever(() =>
        alarm.trigger(title: any(named: 'title'), body: any(named: 'body')));

    await emit(outside); // first out — not yet
    expect(container.read(anchorWatchProvider).status, AnchorWatchStatus.armed);
    await emit(outside); // second consecutive out — drag!

    final state = container.read(anchorWatchProvider);
    expect(state.status, AnchorWatchStatus.dragging);
    expect(state.distanceMeters, greaterThan(state.radiusMeters));
    verify(() =>
            alarm.trigger(title: any(named: 'title'), body: any(named: 'body')))
        .called(1);
  });

  test('an imprecise fix does not count toward a drag', () async {
    gps.current = anchor;
    final notifier = container.read(anchorWatchProvider.notifier);
    await notifier.dropAnchor(boatId: 'boat-1');

    // Outside, but accuracy (100 m) is worse than the 40 m radius → ignored.
    await emit(outside, accuracy: 100);
    await emit(outside, accuracy: 100);

    expect(container.read(anchorWatchProvider).status, AnchorWatchStatus.armed);
    verifyNever(() =>
        alarm.trigger(title: any(named: 'title'), body: any(named: 'body')));
  });

  test('silence keeps the banner but stops re-firing; back inside resets',
      () async {
    gps.current = anchor;
    final notifier = container.read(anchorWatchProvider.notifier);
    await notifier.dropAnchor(boatId: 'boat-1');
    await emit(outside);
    await emit(outside);
    expect(
        container.read(anchorWatchProvider).status, AnchorWatchStatus.dragging);

    await notifier.silenceAlarm();
    expect(container.read(anchorWatchProvider).alarmSilenced, isTrue);

    await emit(inside); // returned inside
    final state = container.read(anchorWatchProvider);
    expect(state.status, AnchorWatchStatus.armed);
    expect(state.alarmSilenced, isFalse);
  });

  test('recenter moves the anchor and clears the drag', () async {
    gps.current = anchor;
    final notifier = container.read(anchorWatchProvider.notifier);
    await notifier.dropAnchor(boatId: 'boat-1');
    await emit(outside);
    await emit(outside);
    expect(
        container.read(anchorWatchProvider).status, AnchorWatchStatus.dragging);

    await notifier.recenter();
    final state = container.read(anchorWatchProvider);
    expect(state.status, AnchorWatchStatus.armed);
    expect(state.anchorPosition, outside); // re-dropped at last position
    expect(state.distanceMeters, 0);
  });

  test('adjustRadius clamps and persists', () async {
    gps.current = anchor;
    final notifier = container.read(anchorWatchProvider.notifier);
    await notifier.dropAnchor(boatId: 'boat-1');

    notifier.adjustRadius(500); // clamps to max
    expect(container.read(anchorWatchProvider).radiusMeters, kMaxAnchorRadiusM);

    notifier.adjustRadius(1); // clamps to min
    expect(container.read(anchorWatchProvider).radiusMeters, kMinAnchorRadiusM);
    final row = await db.getAnchorWatch();
    expect((row!['radius_m'] as num).toDouble(), kMinAnchorRadiusM);
  });

  test('disarm stops the watch and clears persistence', () async {
    gps.current = anchor;
    final notifier = container.read(anchorWatchProvider.notifier);
    await notifier.dropAnchor(boatId: 'boat-1');

    await notifier.disarm();
    expect(container.read(anchorWatchProvider).status, AnchorWatchStatus.idle);
    expect(await db.getAnchorWatch(), isNull);
    verify(() => alarm.stop()).called(1);
  });

  test('recoverWatch restores an armed watch from the database', () async {
    await db.startAnchorWatch(
      boatId: 'boat-1',
      anchorLat: anchor.latitude,
      anchorLon: anchor.longitude,
      radiusM: 55,
      setAt: DateTime(2026, 7, 18, 22),
    );
    final notifier = container.read(anchorWatchProvider.notifier);

    expect(await notifier.hasPersistedWatch(), isTrue);
    expect(await notifier.recoverWatch(), isTrue);

    final state = container.read(anchorWatchProvider);
    expect(state.status, AnchorWatchStatus.armed);
    expect(state.anchorPosition, anchor);
    expect(state.radiusMeters, 55);
    expect(state.boatId, 'boat-1');
  });

  group('background survival', () {
    // The bug this covers: re-arming the GPS stream used to live in the anchor
    // screen's WidgetsBindingObserver, so an armed watch with the phone in a
    // pocket and the screen closed simply stopped checking for drift.
    test('re-arms a stream that went quiet while the app was away', () async {
      gps.current = anchor;
      final notifier = container.read(anchorWatchProvider.notifier);
      await notifier.dropAnchor(boatId: 'boat-1');
      await emit(anchor);
      expect(gps.streamStarts, 1);

      // Two minutes in a pocket with nothing delivered, no screen mounted.
      gpsNow = gpsNow.add(const Duration(minutes: 2));
      lifecycle.leaveAndReturn(away: const Duration(minutes: 2));
      await lifecycle.settle(container);
      await pumpEventQueue();

      expect(gps.streamStarts, 2, reason: 'the watch must re-subscribe');
      expect(container.read(anchorWatchProvider).isArmed, isTrue);
    });

    test('leaves a stream that is still delivering alone', () async {
      gps.current = anchor;
      final notifier = container.read(anchorWatchProvider.notifier);
      await notifier.dropAnchor(boatId: 'boat-1');
      await emit(anchor);

      lifecycle.leaveAndReturn(away: const Duration(seconds: 20));
      await lifecycle.settle(container);
      await pumpEventQueue();

      expect(gps.streamStarts, 1);
    });

    test('a disarmed watch is not resurrected by coming back', () async {
      gps.current = anchor;
      final notifier = container.read(anchorWatchProvider.notifier);
      await notifier.dropAnchor(boatId: 'boat-1');
      await notifier.disarm();

      gpsNow = gpsNow.add(const Duration(minutes: 10));
      lifecycle.leaveAndReturn();
      await lifecycle.settle(container);
      await pumpEventQueue();

      expect(gps.streamStarts, 1);
      expect(container.read(anchorWatchProvider).isArmed, isFalse);
    });
  });
}
