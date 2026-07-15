import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/charts/presentation/providers/chart_provider.dart';
import 'package:navis_mobile/features/charts/presentation/screens/chart_screen.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/ports/presentation/providers/port_provider.dart';

import '../../helpers/helpers.dart';

/// chartProvider's initial center. Markers/tracks used in tests must sit near
/// it, otherwise flutter_map culls them outside the viewport.
const _centerLat = 39.4699;
const _centerLon = -0.3763;

class _FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  _FakeBoatsNotifier(this._boats);

  final List<Boat> _boats;

  @override
  Future<List<Boat>> build() async => _boats;
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => boat;
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

/// Permission granted but location services off: getting a fix throws, which
/// must surface the same banner as a denied permission.
class _ServiceOffGeo extends FakeGeo {
  _ServiceOffGeo() : super(serviceEnabled: false);

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    throw const LocationServiceDisabledException();
  }
}

void main() {
  Future<void> pumpChart(
    WidgetTester tester, {
    List<Boat>? boats,
    List<Trip> trips = const [],
    bool showTracks = false,
  }) async {
    await tester.pumpWidget(
      buildTestApp(
        const ChartScreen(),
        overrides: [
          allPortsProvider.overrideWith((ref) async => []),
          boatsProvider.overrideWith(
            () => _FakeBoatsNotifier(boats ?? [makeBoat()]),
          ),
          boatTripsProvider.overrideWith((ref, boatId) async => trips),
          if (showTracks)
            chartProvider.overrideWith(
              (ref) => ChartNotifier()..toggleTracks(),
            ),
        ],
      ),
    );
    await pumpScreen(tester);
  }

  group('ChartScreen location banner', () {
    testWidgets(
        'permission denied after request shows banner and the '
        'Open settings CTA opens location settings', (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      final fakeGeo = installFakeGeo(
        checkResult: LocationPermission.denied,
        requestResult: LocationPermission.denied,
      );

      await pumpChart(tester);

      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);

      await tester.tap(find.text('Open settings'));
      await tester.pump();

      expect(fakeGeo.openSettingsCalled, isTrue);

      await drain(tester);
    });

    testWidgets('location services disabled shows the same banner',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      GeolocatorPlatform.instance = _ServiceOffGeo();

      await pumpChart(tester);

      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);

      await drain(tester);
    });
  });

  group('ChartScreen with GPS granted', () {
    testWidgets('renders the map and the position overlay, no banner',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      installFakeGeo();

      await pumpChart(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      // makePosition() default: Palma de Mallorca, 4 decimals in the overlay.
      expect(find.text('39.5696, 2.6347'), findsOneWidget);
      expect(find.text('Location unavailable'), findsNothing);

      await drain(tester);
    });

    testWidgets('renders a home-port marker for a boat with coordinates',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      installFakeGeo();
      final boat = makeBoat().copyWith(
        homePortLat: _centerLat,
        homePortLon: _centerLon,
      );

      await pumpChart(tester, boats: [boat]);

      expect(find.byIcon(Icons.sailing), findsOneWidget);

      await drain(tester);
    });

    testWidgets('renders trip-track polylines when showTracks is on',
        (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      installFakeGeo();
      final trip = makeTrip().copyWith(
        trackPoints: [
          TrackPoint(
            latitude: _centerLat - 0.01,
            longitude: _centerLon - 0.01,
            timestamp: DateTime(2026, 4, 26, 10),
            speedKnots: 5,
          ),
          TrackPoint(
            latitude: _centerLat + 0.01,
            longitude: _centerLon + 0.01,
            timestamp: DateTime(2026, 4, 26, 10, 30),
            speedKnots: 6,
          ),
        ],
      );

      await pumpChart(tester, trips: [trip], showTracks: true);

      final layerFinder = find.byType(PolylineLayer);
      expect(layerFinder, findsOneWidget);
      final layer = tester.widget<PolylineLayer>(layerFinder);
      expect(layer.polylines, hasLength(1));
      expect(layer.polylines.first.points, hasLength(2));

      await drain(tester);
    });

    testWidgets('zoom and center-on-GPS controls do not crash', (tester) async {
      setPhoneSize(tester);
      installTileNoiseFilter();
      installFakeGeo();

      await pumpChart(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.my_location));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(FlutterMap), findsOneWidget);

      // The camera moves schedule extra tile-load timers; flush them before
      // disposing so no timer outlives the test.
      await tester.pump(const Duration(seconds: 30));
      await drain(tester);
    });
  });
}
