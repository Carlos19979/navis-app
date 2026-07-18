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
import 'package:navis_mobile/features/anchor/presentation/screens/anchor_alarm_screen.dart';

import '../../helpers/helpers.dart';

class MockAlarmService extends Mock implements AlarmService {}

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  final _controller = StreamController<Position>.broadcast();
  LatLng current = const LatLng(39.5, 2.6);

  Position _pos(LatLng at) => Position(
        latitude: at.latitude,
        longitude: at.longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      _pos(current);
  @override
  Future<Position?> getLastKnownPosition(
          {bool forceLocationManager = false}) async =>
      _pos(current);
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      _controller.stream;

  Future<void> close() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late MockAlarmService alarm;
  late FakeGeolocatorPlatform gps;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, 'navis_cache.db'));
    db = LocalDatabase();
    gps = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = gps;
    alarm = MockAlarmService();
    when(() => alarm.requestPermission()).thenAnswer((_) async {});
    when(() => alarm.stop()).thenAnswer((_) async {});
    when(() => alarm.trigger(
          title: any(named: 'title'),
          body: any(named: 'body'),
        )).thenAnswer((_) async {});
  });

  tearDown(() async {
    await gps.close();
    await db.close();
  });

  List<Override> overrides({required bool pro}) => [
        ...planOverrides(pro: pro),
        localDatabaseProvider.overrideWithValue(db),
        alarmServiceProvider.overrideWithValue(alarm),
      ];

  // The Free-plan branch returns a paywall gate (no FlutterMap), so it is safe
  // and fast to widget-test. The armed/map path is covered by the provider unit
  // test and the E2E journey (a live FlutterMap schedules frames indefinitely,
  // which stalls the widget tester).
  testWidgets('Free users see the paywall gate, not the map', (tester) async {
    await tester.pumpWidget(buildTestApp(
      const AnchorAlarmScreen(boatId: 'boat-1'),
      overrides: overrides(pro: false),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Unlock the anchor watch with Navis Pro'), findsOneWidget);
    expect(find.text('Drop anchor here'), findsNothing);
  });
}
