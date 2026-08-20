import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/features/cost/presentation/screens/cost_analytics_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/screens/document_list_screen.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/logbook_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_stats_screen.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/expenses_screen.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/screens/readiness_screen.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';

import '../helpers/helpers.dart';

/// **The battery invariant, as a number: at rest the app schedules no frames.**
///
/// The seven invariants from #75 and #87 each guard one mechanism — no blur in
/// content, no unbounded `repeat()`, the shimmer stops, no realtime, the
/// notifier owns the GPS, tiles are store-first. This one is stricter and
/// simpler, and it is what the whole redesign was allowed to spend against: a
/// screen may animate on the way in, on a tap, or while data is loading, but
/// once it is sitting there with the user's thumb still, **the framework must
/// have nothing scheduled**.
///
/// That is the difference between an effect and a cost. An entrance is paid
/// once; a gradient is painted into a layer and reused; a blur over a flat
/// canvas is paid 60 times a second forever and hands back the pixels it was
/// given. So this test is what lets the aesthetic answer be «yes» — it puts a
/// measurement under it instead of a promise.
///
/// A failure looks like one of two things:
///  * `pumpAndSettle` times out — something loops without a bound;
///  * the assertion trips — a ticker is still alive with nothing to show for
///    it (a controller nobody stopped, a `repeat()` that slipped in).
void main() {
  /// Pumps [screen], lets everything finish, and then insists that nothing is
  /// still running.
  Future<void> expectStillAtRest(
    WidgetTester tester,
    Widget screen, {
    required List<Override> overrides,
  }) async {
    setPhoneSize(tester);
    installTileNoiseFilter();
    stubPathProvider();
    await tester.pumpWidget(buildTestApp(screen, overrides: overrides));

    // Generous but bounded: entrances are ~400 ms plus a capped stagger, and
    // the decorative float in an empty state plays twice at 2 s.
    await tester.pumpAndSettle();

    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'a ticker is still alive after the screen settled — that is a '
          'frame every 16 ms for as long as the screen is open',
    );
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'the screen asked for another frame with nothing left to draw',
    );

    await drain(tester);
  }

  testWidgets('Today rests', (tester) async {
    await expectStillAtRest(
      tester,
      const TodayScreen(),
      overrides: [
        ...await todayOverrides(),
        ...planOverrides(pro: true),
      ],
    );
  });

  testWidgets('the forecast rests', (tester) async {
    await expectStillAtRest(
      tester,
      const WeatherScreen(),
      overrides: [
        weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
      ],
    );
  });

  testWidgets('the logbook rests', (tester) async {
    await expectStillAtRest(
      tester,
      const LogbookScreen(boatId: 'boat-1'),
      overrides: [
        boatTripsProvider.overrideWith((ref, id) async => [makeTrip()]),
        tripStatsProvider.overrideWith((ref, trips) => makeTripStats()),
      ],
    );
  });

  testWidgets('trip statistics rest', (tester) async {
    await expectStillAtRest(
      tester,
      const TripStatsScreen(boatId: 'boat-1'),
      overrides: [
        allBoatTripsProvider.overrideWith((ref, id) async => [makeTrip()]),
      ],
    );
  });

  testWidgets('the documents list rests', (tester) async {
    await expectStillAtRest(
      tester,
      const DocumentListScreen(boatId: 'boat-1'),
      overrides: [
        boatDocumentsProvider.overrideWith((ref, id) async => [makeDocument()]),
      ],
    );
  });

  testWidgets('readiness rests', (tester) async {
    await expectStillAtRest(
      tester,
      const ReadinessScreen(boatId: 'boat-1'),
      overrides: [
        boatReadinessProvider.overrideWith((ref, id) async => makeReadiness()),
      ],
    );
  });

  testWidgets('the maintenance plan rests', (tester) async {
    await expectStillAtRest(
      tester,
      const MaintenanceScreen(boatId: 'boat-1'),
      overrides: [
        maintenanceTasksProvider.overrideWith(
          (ref, id) async => [makeMaintenanceTask()],
        ),
        maintenanceLogsProvider.overrideWith(
          (ref, id) async => [makeMaintenanceLog()],
        ),
      ],
    );
  });

  testWidgets('the expense ledger rests', (tester) async {
    await expectStillAtRest(
      tester,
      const ExpensesScreen(boatId: 'boat-1'),
      overrides: [
        expensesProvider.overrideWith((ref, id) async => [makeExpense()]),
        expenseSummaryProvider.overrideWith(
          (ref, id) async => const ExpenseSummary(totals: {}, total: 0),
        ),
        boatSplitSummaryProvider.overrideWith(
          (ref, id) async => const <String, ExpenseSplitSummary>{},
        ),
      ],
    );
  });

  testWidgets('cost intelligence rests', (tester) async {
    await expectStillAtRest(
      tester,
      const CostAnalyticsScreen(boatId: 'boat-1'),
      overrides: [
        boatCostAnalyticsProvider.overrideWith(
          (ref, id) async => makeCostAnalytics(),
        ),
        boatAnomaliesProvider.overrideWith(
          (ref, id) async => const <Anomaly>[],
        ),
      ],
    );
  });

  testWidgets('community rests', (tester) async {
    await expectStillAtRest(
      tester,
      const CommunityScreen(),
      overrides: [
        eventsProvider.overrideWith((ref) async => [makeEvent()]),
        myGroupsProvider.overrideWith((ref) async => [makeGroup()]),
        discoverGroupsProvider.overrideWith((ref) async => <Group>[]),
        ...planOverrides(),
      ],
    );
  });

  testWidgets('and the check itself catches a screen that never rests',
      (tester) async {
    // A test that only ever passes is not evidence. This is the failure mode
    // the ten above are guarding against — an unbounded loop — and it proves
    // the assertion fires instead of quietly agreeing.
    setPhoneSize(tester);
    await tester.pumpWidget(
      buildTestAppWithScaffold(
        const _NeverRests(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.hasRunningAnimations, isTrue);
    // `pumpAndSettle` would time out here, which is the other half of how a
    // regression announces itself.
    await drain(tester);
  });
}

/// A perpetual animation, on purpose.
class _NeverRests extends StatefulWidget {
  const _NeverRests();

  @override
  State<_NeverRests> createState() => _NeverRestsState();
}

class _NeverRestsState extends State<_NeverRests>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _c, child: const Text('x'));
}
