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
    await tapUntil(tester, find.text('Expenses'), find.byType(TabBarView));
    await pumpFor(tester, const Duration(milliseconds: 500));
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
