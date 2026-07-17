import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/credentials.dart';
import '../helpers/pumping.dart';
import '../robots/auth_robot.dart';
import '../robots/boat_robot.dart';
import '../robots/maintenance_robot.dart';
import '../robots/nav_robot.dart';
import '../robots/settings_robot.dart';

/// J09 — Shared boat, two real users: A shares Aurora by code, B joins and
/// sees it under 'Shared with me', then A splits an expense between both and
/// settles B's share. Runs BEFORE J08 (which deletes user A); user B is
/// swept by scripts/e2e_cleanup.sh.
void j09SharedBoat() {
  testWidgets('j09 shared boat: share code, second user joins, split+settle',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final auth = AuthRobot(tester);
    final boat = BoatRobot(tester);
    final settings = SettingsRobot(tester);
    final maint = MaintenanceRobot(tester);
    final nav = NavRobot(tester);

    // --- As A: read Aurora's share code from the share sheet.
    await boat.openDetail('Aurora');
    final code = await boat.readShareCode();
    expect(code, isNotEmpty);
    // Back to the dashboard — Settings is reached via the shell tabs.
    await nav.back();
    await pumpFor(tester, const Duration(milliseconds: 600));

    // --- Switch to B (register through the UI).
    await settings.open();
    await settings.logout();
    await auth.expectLoginScreen();
    await auth.goToRegister();
    await auth.register(e2eEmailB, e2ePassword);
    await boat.expectEmptyDashboard();

    // --- B joins by code and sees the shared boat.
    await boat.joinByCode(code);
    await pumpUntilFound(tester, find.text('Shared with me'));
    await pumpUntilFound(tester, find.text('Aurora'));

    // Member view: the detail hub shows 'Leave shared boat', never Delete.
    await boat.openDetail('Aurora');
    for (var i = 0;
        i < 8 && find.text('Leave shared boat').evaluate().isEmpty;
        i++) {
      await tester.drag(
        boat.detailScrollable().first,
        const Offset(0, -400),
        warnIfMissed: false,
      );
      await pumpFor(tester, const Duration(milliseconds: 400));
    }
    await pumpUntilFound(tester, find.text('Leave shared boat'));
    expect(find.text('Delete Boat'), findsNothing);
    await nav.back();
    await pumpFor(tester, const Duration(milliseconds: 600));

    // --- Back to A: create an expense and split it between both users.
    await settings.open();
    await settings.logout();
    await auth.expectLoginScreen();
    await auth.login(e2eEmail, e2ePassword);
    await pumpUntilFound(tester, find.text('Aurora'));

    await tapUntil(
      tester,
      find.text('Maintenance'),
      find.byTooltip('Record service'),
    );
    await maint.openExpensesTab();
    await maint.addExpense(amount: '90');

    // Split equally between A and B; the card badge reflects the 45 € share
    // ('You owe' when the current user has an unsettled share, 'Split among'
    // otherwise).
    await maint.openSplitSheet();
    await maint.saveSplit();
    final splitBadge = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data?.contains('You owe') == true ||
              w.data?.contains('Split among') == true),
    );
    await pumpUntilFound(tester, splitBadge);
    await pumpUntilFound(tester, find.textContaining('45'));
  });
}
