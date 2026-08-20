import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_stats_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../../helpers/helpers.dart';

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  const boatId = 'boat-1';

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// The vertical list. The screen also has horizontal chip strips, so a bare
  /// `scrollUntilVisible` cannot tell which scrollable it means.
  Finder pageScroll() => find.byType(Scrollable).first;

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Trip> trips,
  }) async {
    setPhoneSize(tester);
    await tester.pumpWidget(
      buildTestApp(
        const TripStatsScreen(boatId: boatId),
        overrides: [
          allBoatTripsProvider.overrideWith((ref, id) async => trips),
        ],
      ),
    );
    await pumpFrames(tester);
  }

  /// Two seasons of trips: 2026 (Apr + Jul) and 2025 (Jul).
  List<Trip> twoSeasons() => [
        makeTrip(
          departureTime: DateTime(2026, 4, 10, 10),
          distanceNm: 20,
          maxSpeedKnots: 6,
          duration: const Duration(hours: 4),
          departurePort: 'Palma',
          arrivalPort: 'Soller',
        ),
        makeTrip(
          id: 'trip-2',
          departureTime: DateTime(2026, 7, 12, 9),
          distanceNm: 30,
          maxSpeedKnots: 9.5,
          duration: const Duration(hours: 6),
          departurePort: 'Palma',
          arrivalPort: 'Andratx',
        ),
        makeTrip(
          id: 'trip-3',
          departureTime: DateTime(2025, 7, 3, 9),
          distanceNm: 50,
          maxSpeedKnots: 11,
          duration: const Duration(hours: 10),
          departurePort: 'Ibiza',
          arrivalPort: 'Formentera',
        ),
      ];

  group('TripStatsScreen', () {
    testWidgets('shows shimmer while the logbook loads', (tester) async {
      final completer = Completer<List<Trip>>();

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            allBoatTripsProvider.overrideWith((ref, id) => completer.future),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(NavisShimmer), findsOneWidget);
    });

    testWidgets('displays the screen title', (tester) async {
      await pumpScreen(tester, trips: [makeTrip()]);

      expect(find.text('Trip statistics'), findsOneWidget);
    });

    testWidgets('starts on all time and totals the whole logbook',
        (tester) async {
      await pumpScreen(tester, trips: twoSeasons());

      // 20 + 30 + 50 NM across the three trips.
      expect(find.text('100.0'), findsOneWidget);
      expect(find.text('ALL TIME'), findsOneWidget);
      // 20 h at sea, 3 trips.
      expect(find.textContaining('3 trips'), findsOneWidget);
    });

    testWidgets('every figure is on screen for the selected period',
        (tester) async {
      await pumpScreen(tester, trips: twoSeasons());

      for (final label in [
        'Total Trips',
        'Top speed',
        'Average speed',
        'Fuel consumed',
        'Total engine hours',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Stat card + the section listing the ports themselves.
      expect(find.text('Ports visited'), findsNWidgets(2));
    });

    // The build-5 request: previous years, not just "this year".
    testWidgets('picking a year recomputes every figure for that year',
        (tester) async {
      await pumpScreen(tester, trips: twoSeasons());

      await tester.tap(find.text('2025'));
      await pumpFrames(tester);

      // Only the 2025 trip: 50 NM, one trip, its own top speed.
      expect(find.text('50.0'), findsOneWidget);
      expect(find.textContaining('1 trip'), findsOneWidget);
      expect(find.text('11.0 kn'), findsOneWidget);
    });

    testWidgets('a year offers only the months it has trips in',
        (tester) async {
      await pumpScreen(tester, trips: twoSeasons());

      await tester.tap(find.text('2026'));
      await pumpFrames(tester);

      expect(find.text('Whole year'), findsOneWidget);
      // A chip plus the chart's axis label for the months that have trips…
      expect(find.text('Apr'), findsNWidgets(2));
      expect(find.text('Jul'), findsNWidgets(2));
      // …and only the chart label for a month with none: no chip to tap.
      expect(find.text('Jan'), findsOneWidget);
    });

    testWidgets('picking a month narrows the figures to that month',
        (tester) async {
      await pumpScreen(tester, trips: twoSeasons());

      await tester.tap(find.text('2026'));
      await pumpFrames(tester);
      await tester.tap(find.text('Apr').first);
      await pumpFrames(tester);

      // Only the April trip: 20 NM.
      expect(find.text('20.0'), findsOneWidget);
      expect(find.textContaining('1 trip'), findsOneWidget);
      // The monthly chart is a year-level view; a single month does not need it.
      expect(find.text('Monthly Activity'), findsNothing);
    });

    testWidgets('the monthly chart is shown for a year', (tester) async {
      await pumpScreen(tester, trips: twoSeasons());

      await tester.tap(find.text('2026'));
      await pumpFrames(tester);
      await tester.scrollUntilVisible(
        find.text('Monthly Activity'),
        200,
        scrollable: pageScroll(),
      );
      await tester.pump();

      expect(find.text('Monthly Activity'), findsOneWidget);
    });

    testWidgets('lists which ports were visited, not just how many',
        (tester) async {
      await pumpScreen(tester, trips: twoSeasons());

      await tester.scrollUntilVisible(
        find.text('Palma'),
        200,
        scrollable: pageScroll(),
      );
      await tester.pump();

      expect(find.text('Palma'), findsOneWidget);
      // Palma appears in two trips.
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('Ibiza'), findsOneWidget);
    });

    testWidgets('shows a dash instead of a zero when there is no reading',
        (tester) async {
      await pumpScreen(
        tester,
        trips: [makeTrip(maxSpeedKnots: null, distanceNm: null)],
      );

      expect(find.text('—'), findsWidgets);
    });

    testWidgets('shows the error state with a retry', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            allBoatTripsProvider.overrideWith((ref, id) async {
              calls++;
              throw Exception('Failed to load');
            }),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
      final before = calls;

      await tester.tap(find.text('Retry'));
      await pumpFrames(tester);

      expect(calls, greaterThan(before));
    });

    testWidgets('shows the empty state with no trips', (tester) async {
      await pumpScreen(tester, trips: const []);

      expect(
        find.text('No trips recorded yet'),
        findsOneWidget,
      );
    });
  });
}
