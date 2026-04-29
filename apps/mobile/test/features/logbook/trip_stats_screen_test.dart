import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_stats_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../../helpers/test_helpers.dart';

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

  group('TripStatsScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      final completer = Completer<List<Trip>>();

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) => completer.future,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(NavisShimmer), findsOneWidget);
    });

    testWidgets('displays Trip Statistics title', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => <Trip>[],
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => const TripStats(
                totalTrips: 0,
                totalDistanceNm: 0,
                totalHours: 0,
              ),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('Trip Statistics'), findsOneWidget);
    });

    testWidgets('shows All Time section with correct stat labels',
        (tester) async {
      final trips = [
        makeTrip(),
        makeTrip(
          id: 'trip-2',
          departurePort: 'Barcelona',
          arrivalPort: 'Valencia',
          distanceNm: 113.8,
          maxSpeedKnots: 9.2,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => trips,
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // All Time section header
      expect(find.text('All Time'), findsOneWidget);

      // Stat card labels
      expect(find.text('Trips'), findsWidgets);
      expect(find.text('NM sailed'), findsWidgets);
      expect(find.text('Hours at sea'), findsWidgets);
      expect(find.text('Ports visited'), findsWidgets);
      expect(find.text('Top speed'), findsWidgets);
      expect(find.text('Fuel consumed'), findsWidgets);
    });

    testWidgets('shows correct totalTrips value from stats',
        (tester) async {
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => trips,
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => const TripStats(
                totalTrips: 5,
                totalDistanceNm: 142.3,
                totalHours: 24.5,
              ),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Total trips: "5" should appear in the stats grid
      expect(find.text('5'), findsWidgets);
      // Distance: "142.3"
      expect(find.text('142.3'), findsWidgets);
      // Hours: "24.5"
      expect(find.text('24.5'), findsWidgets);
    });

    testWidgets('shows This Year section', (tester) async {
      final trips = [makeTrip()];
      final thisYear = DateTime.now().year;

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => trips,
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(
        find.text('This Year ($thisYear)'),
        findsOneWidget,
      );
    });

    testWidgets('shows Monthly Activity chart', (tester) async {
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => trips,
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // Monthly Activity chart is below the fold -- scroll to it
      await tester.scrollUntilVisible(
        find.text('Monthly Activity'),
        200,
      );
      await tester.pump();

      expect(find.text('Monthly Activity'), findsOneWidget);
    });

    testWidgets('shows ports visited count from trip data',
        (tester) async {
      final trips = [
        makeTrip(
          departurePort: 'Palma',
          arrivalPort: 'Soller',
        ),
        makeTrip(
          id: 'trip-2',
          departurePort: 'Palma',
          arrivalPort: 'Alcudia',
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => trips,
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // 3 unique ports: Palma, Soller, Alcudia
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('shows error state with retry button',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async =>
                  throw Exception('Failed to load'),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers provider refresh',
        (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async {
                callCount++;
                throw Exception('Network error');
              },
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      final initialCount = callCount;

      await tester.tap(find.text('Retry'));
      await pumpFrames(tester);

      expect(callCount, greaterThan(initialCount));
    });

    testWidgets('shows top speed from trip data', (tester) async {
      final trips = [
        makeTrip(maxSpeedKnots: 9.2),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => trips,
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.text('9.2 kn'), findsOneWidget);
    });

    testWidgets('shows dash for top speed when no speed data',
        (tester) async {
      final trips = [
        makeTrip(maxSpeedKnots: null),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const TripStatsScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => trips,
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => const TripStats(
                totalTrips: 1,
                totalDistanceNm: 28.5,
                totalHours: 4.5,
              ),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      // When maxSpeed is 0, shows '-'
      expect(find.text('-'), findsWidgets);
    });
  });
}
