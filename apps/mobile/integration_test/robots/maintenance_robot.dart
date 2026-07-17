import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_button.dart';
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

  /// Records a one-off service with a cost through the bottom sheet
  /// (app-bar action, tooltip 'Record service').
  Future<void> recordService({
    required String type,
    required String cost,
  }) async {
    await ensureMaintenanceTab();
    await tapUntil(
      tester,
      find.byTooltip('Record service'),
      find.widgetWithText(NavisButton, 'Save'),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    await _sheetField('Type (e.g. oil change)', type);
    await _sheetField('Cost € (opt.)', cost);
    await tapUntilGone(
      tester,
      find.widgetWithText(NavisButton, 'Save'),
      find.widgetWithText(NavisButton, 'Save'),
    );
  }

  /// Adds a recurring task (months interval) via the FAB (tooltip 'Add task').
  Future<void> addTask({required String name, String months = '12'}) async {
    await ensureMaintenanceTab();
    await tapUntil(
      tester,
      find.byTooltip('Add task'),
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

  Future<void> openExpensesTab() async {
    // 'Total spent' only renders on the Expenses tab — TabBarView exists on
    // both tabs, which would satisfy tapUntil's early-exit before the tap.
    await tapUntil(tester, find.text('Expenses'), find.text('Total spent'));
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  /// Adds an expense via the Expenses-tab FAB (default category chip kept).
  Future<void> addExpense({required String amount}) async {
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
