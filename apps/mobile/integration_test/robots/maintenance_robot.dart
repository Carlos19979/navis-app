import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/features/maintenance/presentation/widgets/expense_period_picker.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

import '../helpers/pumping.dart';

class MaintenanceRobot {
  MaintenanceRobot(this.tester);

  final WidgetTester tester;

  /// Makes sure the Maintenance tab (not Expenses) is selected, with no
  /// snackbar in flight (an active snackbar shifts the FAB and eats taps).
  Future<void> ensureMaintenanceTab() async {
    await pumpUntilGone(
      tester,
      find.byType(SnackBar),
      timeout: const Duration(seconds: 8),
    );
    final tab = find.widgetWithText(Tab, 'Maintenance');
    await pumpUntilFound(tester, tab);
    await tester.tap(tab.first);
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  /// Creates a recurring task through the FAB sheet: name, interval, and the
  /// due date the sheet derives from it.
  Future<void> addTask({required String name, String months = '12'}) async {
    await ensureMaintenanceTab();
    await tapUntil(
      tester,
      find.byTooltip('New service'),
      find.widgetWithText(NavisTextField, 'Task name'),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    await _sheetField('Task name', name);
    await _sheetField('Every (months)', months);
    await tapUntilGone(
      tester,
      find.widgetWithText(NavisButton, 'Save'),
      find.widgetWithText(NavisButton, 'Save'),
    );
    await pumpUntilFound(tester, find.text(name));
  }

  /// Creates a one-off job: same sheet, with the schedule switched off.
  Future<void> addOneOffTask({required String name}) async {
    await ensureMaintenanceTab();
    await tapUntil(
      tester,
      find.byTooltip('New service'),
      find.widgetWithText(NavisTextField, 'Task name'),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    await _sheetField('Task name', name);
    await tester.tap(find.text('One-off').last);
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tapUntilGone(
      tester,
      find.widgetWithText(NavisButton, 'Save'),
      find.widgetWithText(NavisButton, 'Save'),
    );
    await pumpUntilFound(tester, find.text(name));
  }

  /// Marks a task as done with a cost — the one button that writes the history
  /// entry and moves the due date.
  Future<void> markTaskDone({
    required String name,
    required String cost,
  }) async {
    await ensureMaintenanceTab();
    await pumpUntilFound(tester, find.text(name));
    // The Done button sits on the task's own card.
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byType(NavisCard),
    );
    await tapUntil(
      tester,
      find.descendant(of: card.first, matching: find.text('Done')),
      find.widgetWithText(NavisTextField, 'Cost € (opt.)'),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    await _sheetField('Cost € (opt.)', cost);
    await tapUntilGone(
      tester,
      find.widgetWithText(NavisButton, 'Save'),
      find.widgetWithText(NavisButton, 'Save'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// Opens a task and checks it lists the times it has been carried out.
  Future<void> checkTaskHistory({required String name}) async {
    await ensureMaintenanceTab();
    await tapUntil(tester, find.text(name), find.text('Times carried out'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    // Dismiss the sheet by tapping the barrier above it.
    await tester.tapAt(const Offset(20, 20));
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  Future<void> openExpensesTab() async {
    // 'Period total' only renders on the Expenses tab — TabBarView exists on
    // both tabs, which would satisfy tapUntil's early-exit before the tap.
    // (The old 'Total spent' summary card was replaced by the period ledger.)
    await tapUntil(tester, find.text('Expenses'), find.text('Period total'));
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  /// Exercises the period picker and a category filter on the expenses ledger.
  ///
  /// The Month/Year segmented toggle with `‹ ›` arrows is gone: the period is now
  /// one pill that opens a month/year picker (ExpensePeriodSelector). The pill
  /// carries the *localized* period label ('July 2026'), so it is located by its
  /// widget type, not by text.
  Future<void> checkExpensesPeriods() async {
    await pumpUntilFound(tester, find.text('Period total'));
    final selector = find.byType(ExpensePeriodSelector);

    // Whole year → per-month subtotals.
    await tapUntil(tester, selector, find.text('Select period'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapUntilGone(
      tester,
      find.text('Whole year'),
      find.byType(AlertDialog),
    );
    await pumpUntilFound(tester, find.text('Period total'));

    // Back to the current month, picked from the dialog's month grid.
    await tapUntil(tester, selector, find.text('Select period'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    final thisMonth = DateFormat.MMM('en').format(DateTime.now());
    await tapUntilGone(
      tester,
      find.widgetWithText(ChoiceChip, thisMonth),
      find.byType(AlertDialog),
    );
    await pumpUntilFound(tester, find.text('Period total'));

    // Filter to Fuel (the category addExpense uses), then back to All.
    final fuel = find.widgetWithText(FilterChip, 'Fuel');
    if (fuel.evaluate().isNotEmpty) {
      await tester.tap(fuel.first);
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(FilterChip, 'All').first);
      await pumpFor(tester, const Duration(milliseconds: 400));
    }
  }

  /// Adds an expense via the Expenses-tab FAB (default category chip kept).
  /// When [liters] is given (fuel), fills the litres field that appears once
  /// the Fuel category is selected, exercising the €/L capture.
  Future<void> addExpense({required String amount, String? liters}) async {
    await pumpUntilGone(
      tester,
      find.byType(SnackBar),
      timeout: const Duration(seconds: 8),
    );
    await tapUntil(
      tester,
      find.byTooltip('New expense'),
      find.widgetWithText(NavisTextField, 'Amount €'),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    // Category is required and starts unselected — pick Fuel.
    await tester.tap(find.text('Fuel').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await _sheetField('Amount €', amount);
    if (liters != null) {
      // The litres field only renders for the fuel category.
      await _sheetField('Liters (optional)', liters);
    }
    await tapUntilGone(
      tester,
      find.widgetWithText(NavisButton, 'Save'),
      find.widgetWithText(NavisButton, 'Save'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// Opens the split sheet from the expense card's groups icon (Pro).
  Future<void> openSplitSheet() async {
    await pumpUntilGone(
      tester,
      find.byType(SnackBar),
      timeout: const Duration(seconds: 8),
    );
    await tapUntil(
      tester,
      find.byTooltip('Split expense'),
      find.text('Split equally'),
      timeout: const Duration(seconds: 8),
    );
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Split equally').first, warnIfMissed: false);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  Future<void> saveSplit() async {
    await tapUntilGone(
      tester,
      find.widgetWithText(NavisButton, 'Save'),
      find.text('Split equally'),
      timeout: const Duration(seconds: 10),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  Future<void> _sheetField(String label, String value) async {
    final field = find.widgetWithText(NavisTextField, label);
    await pumpUntilFound(tester, field);
    final editable = find.descendant(
      of: field.first,
      matching: find.byType(TextField),
    );
    await enterTextChecked(tester, editable, value);
  }
}
