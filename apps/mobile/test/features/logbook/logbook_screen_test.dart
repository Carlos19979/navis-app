import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/logbook_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/stats_summary.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/trip_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

import '../../helpers/helpers.dart';

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  const boatId = 'boat-1';

  // Helper: pump enough frames for async providers and animations
  // without calling pumpAndSettle (which hangs on looping animations).
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump(); // trigger provider future
    await tester.pump(const Duration(seconds: 1)); // animations
  }

  group('LogbookScreen', () {
    testWidgets('shows shimmer loading state', (tester) async {
      final completer = Completer<List<Trip>>();

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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

    testWidgets('renders trip list with TripCard widgets', (tester) async {
      final trips = [
        makeTrip(),
        makeTrip(id: 'trip-2', departurePort: 'Barcelona'),
      ];

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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

      expect(find.byType(TripCard), findsNWidgets(2));
      expect(find.text('Palma de Mallorca'), findsOneWidget);
      expect(find.text('Barcelona'), findsOneWidget);
    });

    testWidgets('shows stats summary when trips exist', (tester) async {
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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

      expect(find.byType(StatsSummary), findsOneWidget);
      // StatsSummary displays trips, distance NM, hours
      expect(find.text('5'), findsOneWidget); // totalTrips
      expect(find.text('142 NM'), findsOneWidget); // totalDistanceNm
      expect(find.text('25'), findsOneWidget); // totalHours rounded
    });

    testWidgets('shows empty state with CTA when no trips', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => <Trip>[],
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(NavisEmptyState), findsOneWidget);
      expect(
        find.text('No trips recorded yet. Start your first trip!'),
        findsOneWidget,
      );
      expect(find.text('Record Trip'), findsOneWidget);
    });

    testWidgets('FAB is present with Record trip tooltip', (tester) async {
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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
        find.byType(FloatingActionButton),
        findsOneWidget,
      );
      expect(
        find.text('Start Trip'),
        findsOneWidget,
      );
    });

    testWidgets('app bar has Statistics button', (tester) async {
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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

      expect(find.byTooltip('Statistics'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => throw Exception('Network error'),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(NavisErrorWidget), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers provider refresh', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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

      // Tap retry
      await tester.tap(find.text('Retry'));
      await pumpFrames(tester);

      expect(callCount, greaterThan(initialCount));
    });

    testWidgets('pull-to-refresh triggers provider invalidation',
        (tester) async {
      var callCount = 0;
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async {
                callCount++;
                return trips;
              },
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      final initialCount = callCount;

      // Pull to refresh: drag down the list
      await tester.fling(
        find.byType(ListView),
        const Offset(0, 300),
        1000,
      );
      await pumpFrames(tester);

      expect(callCount, greaterThan(initialCount));
    });

    testWidgets('TripCard widget is rendered and tappable', (tester) async {
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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

      final tripCard = find.byType(TripCard);
      expect(tripCard, findsOneWidget);

      // TripCard renders departure port text
      expect(find.text('Palma de Mallorca'), findsOneWidget);
    });

    testWidgets('FAB is hidden when the member cannot record trips',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => [makeTrip()],
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
            boatProvider.overrideWith(
              (ref, id) async => makeBoat(id: id).copyWith(
                isOwner: false,
                permissions: const BoatPermissions(canRecordTrips: false),
              ),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('TripCard tap navigates to the trip detail', (tester) async {
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const LogbookScreen(boatId: boatId),
          spy: spy,
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => [makeTrip()],
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      await tester.tap(find.byType(TripCard));
      await pumpFrames(tester);

      expect(spy.last, '/trips/trip-1');
    });

    testWidgets('Statistics button navigates to the stats page',
        (tester) async {
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const LogbookScreen(boatId: boatId),
          spy: spy,
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => [makeTrip()],
            ),
            tripStatsProvider.overrideWith(
              (ref, trips) => makeTripStats(),
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Statistics'));
      await pumpFrames(tester);

      expect(spy.last, '/boats/$boatId/stats');
    });

    testWidgets('empty state CTA navigates to the trip precheck',
        (tester) async {
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const LogbookScreen(boatId: boatId),
          spy: spy,
          overrides: [
            boatTripsProvider.overrideWith(
              (ref, boatId) async => <Trip>[],
            ),
          ],
        ),
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Record Trip'));
      await pumpFrames(tester);

      expect(spy.last, '/boats/$boatId/precheck');
    });

    testWidgets('displays Logbook title in app bar', (tester) async {
      final trips = [makeTrip()];

      await tester.pumpWidget(
        buildTestApp(
          const LogbookScreen(boatId: boatId),
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

      expect(find.text('Logbook'), findsOneWidget);
    });
  });
}
