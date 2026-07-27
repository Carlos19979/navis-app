import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/maintenance/data/maintenance_models.dart';
import 'package:navis_mobile/features/maintenance/data/maintenance_repository.dart';
import 'package:navis_mobile/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:navis_mobile/features/maintenance/presentation/widgets/expense_period_picker.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';

import '../../helpers/helpers.dart';

/// The user asked for the cost-intelligence shortcut to be gone from
/// "Maintenance & expenses": the same screen is already one tap away from the
/// boat's detail screen, and two doors to one room read as two features.
///
/// Absence is trivial to undo by accident, so these tests assert it directly:
/// no icon, no label, and — with a [RouteSpy] — no reachable route to
/// `/boats/{id}/costs` from anywhere in the bar.
void main() {
  const boatId = 'boat-1';

  /// Every control the app bar renders (Back plus any action).
  final appBarButtons = find.descendant(
    of: find.byType(NavisAppBar),
    matching: find.byType(IconButton),
  );

  /// App-bar controls other than Back.
  final appBarActions = find.descendant(
    of: find.byType(NavisAppBar),
    matching: find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip != 'Go back',
      description: 'app bar action (Back excluded)',
    ),
  );

  Widget buildSubject({RouteSpy? spy, bool pro = true}) {
    final overrides = <Override>[
      // Pro so a re-added shortcut would navigate straight through instead of
      // stopping at the paywall: the tests must see the navigation attempt.
      ...planOverrides(pro: pro),
      maintenanceTasksProvider.overrideWith(
        (ref, id) async => <MaintenanceTask>[],
      ),
      maintenanceLogsProvider.overrideWith(
        (ref, id) async => <MaintenanceLog>[],
      ),
      expensesProvider.overrideWith((ref, id) async => <Expense>[]),
      expenseSummaryProvider.overrideWith(
        (ref, id) async => const ExpenseSummary(totals: {}, total: 0),
      ),
      boatSplitSummaryProvider.overrideWith(
        (ref, id) async => const <String, ExpenseSplitSummary>{},
      ),
    ];
    const screen = MaintenanceScreen(boatId: boatId);
    return spy == null
        ? buildTestApp(screen, overrides: overrides)
        : buildRoutedTestApp(screen, spy: spy, overrides: overrides);
  }

  Future<void> openExpensesTab(WidgetTester tester) async {
    await tester.tap(find.text('Expenses'));
    // One frame to start the tab transition, one to finish it (the page is
    // built lazily during the animation) and one for the async providers.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  /// Taps whatever action the app bar exposes. Today there is none — that is
  /// the requirement — so this taps nothing; if a shortcut comes back, its tap
  /// is what the RouteSpy assertion catches.
  Future<void> tapAppBarActions(WidgetTester tester) async {
    if (appBarActions.evaluate().isEmpty) return;
    // One tap is enough: a navigation replaces the screen under test.
    await tester.tap(appBarActions.first);
    await pumpScreen(tester);
  }

  /// Ends a test that visited the expenses tab: its shimmer/entrance
  /// animations leave timers behind.
  Future<void> finish(WidgetTester tester) async {
    await drain(tester);
    await tester.pump(const Duration(seconds: 5));
  }

  group('MaintenanceScreen has no cost-intelligence shortcut', () {
    testWidgets('maintenance tab shows neither the icon nor the label',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(
        find.byIcon(Icons.insights_rounded),
        findsNothing,
        reason: 'cost intelligence is reached from the boat detail screen',
      );
      expect(find.text('Cost intelligence'), findsNothing);
      expect(
        tester.widgetList<IconButton>(appBarButtons).map((b) => b.tooltip),
        ['Go back'],
        reason: 'Back is the only control the bar should have',
      );
    });

    testWidgets('expenses tab shows neither the icon nor the label',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openExpensesTab(tester);

      expect(find.byIcon(Icons.insights_rounded), findsNothing);
      expect(find.text('Cost intelligence'), findsNothing);
      expect(
        tester.widgetList<IconButton>(appBarButtons).map((b) => b.tooltip),
        ['Go back'],
      );

      await finish(tester);
    });

    testWidgets('nothing in the bar navigates to the costs route',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(spy: spy));
      await pumpScreen(tester);

      await tapAppBarActions(tester);
      // Only worth visiting the second tab while the screen is still mounted:
      // a navigation would already have replaced it.
      if (find.byType(MaintenanceScreen).evaluate().isNotEmpty) {
        await openExpensesTab(tester);
        await tapAppBarActions(tester);
      }

      expect(
        spy.locations.where((l) => l.contains('/costs')),
        isEmpty,
        reason: 'the screen must offer no route to /boats/$boatId/costs',
      );
      expect(spy.locations, isEmpty);

      await finish(tester);
    });
  });

  group('MaintenanceScreen keeps the rest of its bar', () {
    testWidgets('title, back button and the two tabs are intact',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('Maintenance & expenses'), findsOneWidget);
      expect(find.byTooltip('Go back'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(2));
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
    });

    testWidgets('both tabs still open their own content', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      expect(find.text('No maintenance tasks yet'), findsOneWidget);

      await openExpensesTab(tester);

      expect(find.text('No expenses in this period'), findsOneWidget);

      await finish(tester);
    });
  });

  group('MaintenanceScreen period selector', () {
    testWidgets('the period bar is a picker, not chevron stepping',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openExpensesTab(tester);

      // One tappable control that opens a picker.
      expect(find.byType(ExpensePeriodSelector), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

      // The ‹ › steppers that needed twelve taps to reach last summer, and the
      // Month/Year toggle beside them, are gone from the period bar.
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byTooltip('Previous'), findsNothing);
      expect(find.byTooltip('Next'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is SegmentedButton,
          description: 'Month/Year segmented toggle',
        ),
        findsNothing,
      );

      await finish(tester);
    });

    testWidgets('chevrons live inside the picker dialog only', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openExpensesTab(tester);

      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();

      // Stepping the year inside the dialog is legitimate: it does not cost a
      // reload per tap and the month grid is right there.
      expect(find.text('Select period'), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.byIcon(Icons.chevron_left)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
      expect(find.text('Whole year'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dismissed: the ledger is back to a bar with no steppers.
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(ExpensePeriodSelector), findsOneWidget);

      await finish(tester);
    });
  });
}
