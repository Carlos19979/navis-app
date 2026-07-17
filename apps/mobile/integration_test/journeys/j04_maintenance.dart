import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/readiness/presentation/widgets/readiness_card.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/boat_robot.dart';
import '../robots/maintenance_robot.dart';
import '../robots/nav_robot.dart';

/// J04 — Maintenance, cost analytics, readiness, bookings: data entered in
/// one feature must show up in the others (Pro plan set in J02).
void j04Maintenance() {
  testWidgets('j04 maintenance/costs/readiness/bookings flow', (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final boat = BoatRobot(tester);
    final maint = MaintenanceRobot(tester);
    final nav = NavRobot(tester);

    // Focus dashboard → Maintenance.
    await tapUntil(
      tester,
      find.text('Maintenance'),
      find.byTooltip('Record service'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    // One-off service with a cost + a recurring task.
    await maint.recordService(type: 'Oil change', cost: '120');
    await pumpUntilFound(tester, find.textContaining('Oil change'));
    await maint.addTask(name: 'Antifouling', months: '18');

    // Cost analytics (Pro): the recorded 120 € must appear.
    await tapUntil(
      tester,
      find.byIcon(Icons.insights_rounded),
      find.text('Cost intelligence'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    await pumpUntilFound(tester, find.textContaining('120'));
    await nav.back();

    // Expenses ledger (round #52): add an expense, then exercise the
    // month/year selector + category filter.
    await maint.openExpensesTab();
    await maint.addExpense(amount: '75');
    await maint.checkExpensesPeriods();

    // Readiness from the dashboard card: reflects the documents from J03.
    await nav.back();
    await nav.home();
    await tapUntil(
      tester,
      find.byType(ReadinessCard),
      find.text('Readiness'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    await nav.back();

    // Bookings (Pro, shared-boat coordination): create one via the pickers.
    await boat.openDetail('Aurora');
    await boat.openTile('Bookings', find.byType(FloatingActionButton));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tapUntil(
      tester,
      find.byType(FloatingActionButton),
      find.text('OK'),
    );
    // Date → start time → end time, then the purpose dialog.
    for (var i = 0; i < 3; i++) {
      await pumpUntilFound(tester, find.text('OK'));
      await tester.tap(find.text('OK').last);
      await pumpFor(tester, const Duration(milliseconds: 600));
    }
    final purposeField = find.byType(TextField);
    await pumpUntilFound(tester, purposeField);
    await tester.enterText(purposeField.last, 'E2E outing');
    await tester.pump(const Duration(milliseconds: 200));
    final saveBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Save'),
    );
    if (saveBtn.evaluate().isNotEmpty) {
      await tester.tap(saveBtn.last);
    }
    await pumpFor(tester, const Duration(seconds: 1));
    await pumpUntilFound(tester, find.textContaining('E2E outing'));

    // Round #46: a second booking on the same default slot overlaps the
    // first; the API returns 409 → 'Book anyway' forces it.
    await tapUntil(
      tester,
      find.byType(FloatingActionButton),
      find.text('OK'),
    );
    for (var i = 0; i < 3; i++) {
      await pumpUntilFound(tester, find.text('OK'));
      await tester.tap(find.text('OK').last);
      await pumpFor(tester, const Duration(milliseconds: 600));
    }
    final purpose2 = find.byType(TextField);
    await pumpUntilFound(tester, purpose2);
    await tester.enterText(purpose2.last, 'Overlap outing');
    await tester.pump(const Duration(milliseconds: 200));
    final save2 = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Save'),
    );
    await tester.tap(save2.last);
    await pumpFor(tester, const Duration(seconds: 1));

    // The overlap confirmation → force the booking.
    await pumpUntilFound(tester, find.text('Book anyway'));
    await tester.tap(find.text('Book anyway'));
    await pumpFor(tester, const Duration(seconds: 1));
    await pumpUntilFound(tester, find.textContaining('Overlap outing'));
  });
}
