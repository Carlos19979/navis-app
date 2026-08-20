import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/expenses_screen.dart';
import 'package:navis_mobile/features/passport/presentation/passport_export.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';

import '../../helpers/helpers.dart';
import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';

class MockSharedRepository extends Mock implements SharedRepository {}

void main() {
  setUpAll(() async {
    await initFakeSupabase();
  });

  /// Overrides for every provider the maintenance screen touches, so both
  /// tabs render without hitting the network.
  List<Override> maintenanceOverrides({required bool pro}) => [
        ...planOverrides(pro: pro),
        maintenanceTasksProvider.overrideWith(
          (ref, id) async => const <MaintenanceTask>[],
        ),
        maintenanceLogsProvider.overrideWith(
          (ref, id) async => const <MaintenanceLog>[],
        ),
        // Current-month date so the expenses ledger (defaults to this month)
        // shows the card and its split button.
        expensesProvider.overrideWith(
          (ref, id) async => [
            makeExpense(
              incurredOn: DateTime(DateTime.now().year, DateTime.now().month),
            ),
          ],
        ),
        expenseSummaryProvider.overrideWith(
          (ref, id) async =>
              const ExpenseSummary(totals: {'combustible': 85.5}, total: 85.5),
        ),
        boatSplitSummaryProvider.overrideWith(
          (ref, id) async => const <String, ExpenseSplitSummary>{},
        ),
      ];

  // Cost intelligence is reached from the boat's detail screen. It used to have
  // a second entry point in the maintenance screen's app bar, which was removed
  // as duplication — the gating itself is unchanged.
  group('cost intelligence gating', () {
    Future<RouteSpy> pumpAndTapInsights(
      WidgetTester tester, {
      required bool pro,
    }) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const TodayScreen(),
          spy: spy,
          overrides: [
            ...await todayOverrides(),
            ...planOverrides(pro: pro),
            boatReadinessProvider.overrideWith(
              (ref, id) async => makeReadiness(),
            ),
          ],
        ),
      );
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        find.text('Cost intelligence'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Cost intelligence'));
      await pumpScreen(tester);
      return spy;
    }

    testWidgets('Free sees the paywall and does not navigate', (tester) async {
      final spy = await pumpAndTapInsights(tester, pro: false);

      expectPaywall();
      expect(spy.locations, isEmpty);
    });

    testWidgets('Pro navigates to cost analytics', (tester) async {
      final spy = await pumpAndTapInsights(tester, pro: true);

      expectPaywall(shown: false);
      expect(spy.last, '/boats/boat-1/costs');
    });
  });

  group('expense split gating', () {
    Future<RouteSpy> pumpAndTapSplit(
      WidgetTester tester, {
      required bool pro,
      List<Override> overrides = const [],
    }) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          // The ledger is its own route now, so there is no tab to tap first.
          const ExpensesScreen(boatId: 'boat-1'),
          spy: spy,
          overrides: [...maintenanceOverrides(pro: pro), ...overrides],
        ),
      );
      await pumpScreen(tester);
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Split expense'));
      await pumpScreen(tester);
      return spy;
    }

    testWidgets('Free opens the split sheet (splitting is free — no paywall)',
        (tester) async {
      final shared = MockSharedRepository();
      when(() => shared.listSplits(any(), any()))
          .thenAnswer((_) async => const <ExpenseSplit>[]);

      await pumpAndTapSplit(
        tester,
        pro: false,
        overrides: [
          sharedRepositoryProvider.overrideWithValue(shared),
          boatMembersProvider.overrideWith(
            (ref, id) async => [makeBoatMember()],
          ),
        ],
      );

      expectPaywall(shown: false);
      expect(find.text('Split expense'), findsOneWidget);
      expect(find.text('Split equally'), findsOneWidget);
    });

    testWidgets('Pro opens the split sheet', (tester) async {
      final shared = MockSharedRepository();
      when(() => shared.listSplits(any(), any()))
          .thenAnswer((_) async => const <ExpenseSplit>[]);

      await pumpAndTapSplit(
        tester,
        pro: true,
        overrides: [
          sharedRepositoryProvider.overrideWithValue(shared),
          boatMembersProvider.overrideWith(
            (ref, id) async => [makeBoatMember()],
          ),
        ],
      );

      expectPaywall(shown: false);
      expect(find.text('Split expense'), findsOneWidget);
      expect(find.text('Split equally'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
    });
  });

  group('community create-group gating', () {
    Future<RouteSpy> pumpAndTapCreateGroup(
      WidgetTester tester, {
      required bool pro,
    }) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const CommunityScreen(),
          spy: spy,
          overrides: [
            ...planOverrides(pro: pro),
            eventsProvider.overrideWith((ref) async => const <Event>[]),
            myGroupsProvider.overrideWith((ref) async => [makeGroup()]),
            discoverGroupsProvider.overrideWith(
              (ref) async => const <Group>[],
            ),
          ],
        ),
      );
      // No tab to open first, and the create button is always on screen.
      await pumpFrames(tester, frames: 8);
      await tester.tap(find.byTooltip('Create club'));
      await pumpScreen(tester);
      return spy;
    }

    testWidgets('Free sees the paywall and does not navigate', (tester) async {
      final spy = await pumpAndTapCreateGroup(tester, pro: false);

      expectPaywall();
      expect(spy.locations, isEmpty);
    });

    testWidgets('Pro navigates to the new group page', (tester) async {
      final spy = await pumpAndTapCreateGroup(tester, pro: true);

      expectPaywall(shown: false);
      expect(spy.last, '/groups/new');
    });
  });

  group('boat detail bookings gating', () {
    Future<RouteSpy> pumpAndTapBookings(
      WidgetTester tester, {
      required bool pro,
    }) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedTestApp(
          const TodayScreen(),
          spy: spy,
          overrides: [
            ...await todayOverrides(),
            ...planOverrides(pro: pro),
            boatReadinessProvider.overrideWith(
              (ref, id) async => makeReadiness(),
            ),
          ],
        ),
      );
      await pumpScreen(tester);

      await tester.scrollUntilVisible(
        find.text('Bookings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      await tester.tap(find.text('Bookings'));
      await pumpScreen(tester);
      return spy;
    }

    testWidgets('Free sees the paywall and does not navigate', (tester) async {
      final spy = await pumpAndTapBookings(tester, pro: false);

      expectPaywall();
      expect(spy.locations, isEmpty);
    });

    testWidgets('Pro navigates to the bookings page', (tester) async {
      final spy = await pumpAndTapBookings(tester, pro: true);

      expectPaywall(shown: false);
      expect(spy.last, '/boats/boat-1/bookings');
    });
  });

  group('passport export gating', () {
    testWidgets('Free sees the paywall and the export aborts on dismiss',
        (tester) async {
      setPhoneSize(tester);
      final billing = MockBillingService();
      when(billing.allPackages).thenAnswer((_) async => const []);

      await tester.pumpWidget(
        buildTestApp(
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => exportBoatPassport(context, ref, makeBoat()),
                  child: const Text('export'),
                ),
              ),
            ),
          ),
          overrides: [...planOverrides(), billingOverride(billing)],
        ),
      );
      await tester.tap(find.text('export'));
      await pumpScreen(tester);

      expectPaywall();
      // The PDF spinner dialog must not be open behind the paywall.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Dismiss the paywall via the modal barrier: the export aborts.
      await tester.tapAt(const Offset(20, 20));
      await pumpScreen(tester);

      expectPaywall(shown: false);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Could not generate the passport'), findsNothing);
    });
  });
}
