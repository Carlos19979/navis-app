import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/readiness/presentation/widgets/readiness_card.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/boat_robot.dart';
import '../robots/booking_robot.dart';
import '../robots/maintenance_robot.dart';
import '../robots/nav_robot.dart';

/// J04 — Maintenance, cost analytics, readiness, bookings: data entered in
/// one feature must show up in the others (Pro plan set in J02).
///
/// Everything about the boat is reached from the detail hub now: the dashboard
/// card only offers Documents and Logbook, and Cost intelligence lost its
/// shortcut from the Maintenance app bar.
void j04Maintenance() {
  testWidgets('j04 maintenance/costs/readiness/bookings flow', (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final boat = BoatRobot(tester);
    final maint = MaintenanceRobot(tester);
    final booking = BookingRobot(tester);
    final nav = NavRobot(tester);

    // Boat detail hub → Maintenance & expenses.
    await boat.openDetail('Aurora');
    final maintenanceMarker = find.byTooltip('New service');
    await boat.openTile('Maintenance & expenses', maintenanceMarker);

    // A one-off job carried out with a cost, plus a recurring service.
    await maint.addOneOffTask(name: 'Oil change');
    await maint.markTaskDone(name: 'Oil change', cost: '120');
    await maint.addTask(name: 'Antifouling', months: '18');
    // Each task keeps its own history of every time it was carried out.
    await maint.checkTaskHistory(name: 'Oil change');

    // Cost intelligence (Pro) hangs off the hub, not off the Maintenance app bar
    // (its Icons.insights_rounded action was removed on purpose). The 120 € just
    // recorded must appear — asserted before the expense below, while it is
    // still the only spend.
    await boat.backToHub(maintenanceMarker);
    await boat.openTile('Cost intelligence', find.text('Total spend'));
    await pumpFor(tester, const Duration(seconds: 1));
    await pumpUntilFound(tester, find.textContaining('120'));
    await boat.backToHub(find.text('Total spend'));

    // Expenses ledger: add an expense, then exercise the period picker and the
    // category filter.
    await boat.openTile('Maintenance & expenses', maintenanceMarker);
    await maint.openExpensesTab();
    // Fuel expense with litres → cost intelligence can derive €/L.
    await maint.addExpense(amount: '75', liters: '50');
    await maint.checkExpensesPeriods();
    await boat.backToHub(maintenanceMarker);

    // Bookings (Pro, shared-boat coordination): a range booking, then a second
    // one on the same default slot — the API answers 409 and 'Book anyway'
    // forces it through.
    await boat.openTile('Bookings', BookingRobot.screenMarker);
    await booking.create('E2E outing');
    await booking.createExpectingOverlap('Overlap outing');
    await boat.backToHub(BookingRobot.screenMarker);

    // Readiness from the dashboard card: reflects the documents from J03.
    await boat.closeDetail();
    await nav.home();
    await tapUntil(
      tester,
      find.byType(ReadinessCard),
      find.text('Readiness'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    await nav.back();
  });
}
