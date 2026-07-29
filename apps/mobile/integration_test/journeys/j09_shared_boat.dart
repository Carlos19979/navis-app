import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/credentials.dart';
import '../helpers/pumping.dart';
import '../robots/auth_robot.dart';
import '../robots/boat_robot.dart';
import '../robots/logbook_robot.dart';
import '../robots/maintenance_robot.dart';
import '../robots/nav_robot.dart';
import '../robots/permissions_robot.dart';
import '../robots/settings_robot.dart';

/// J09 — Shared boat, two real users, the full permission cycle.
///
/// A shares Aurora; B joins by code as a **viewer** and finds every write it
/// does not hold blocked *before* doing the work (documents, maintenance,
/// expenses show the padlock and the reason; recording is not even offered);
/// A grants "record trips" from Crew and permissions; B then records and saves a
/// real trip. That save is the 403 that made shared boats — a Pro feature —
/// useless: it landed after the whole trip was sailed.
///
/// This is the flow nothing else can cover: two accounts against the real API,
/// where the owner's grant happens on a different device from the block.
///
/// Order-dependent, like the rest of the suite: needs Aurora (J02) with
/// documents (J03) and at least one trip (J05). Runs BEFORE J08 (which deletes
/// user A) and ends signed in as A so J08 tears down the right account. User B
/// is swept by `scripts/e2e_cleanup.sh`.
void j09SharedBoat() {
  testWidgets('j09 shared boat: viewer blocked → owner grants → viewer records',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final auth = AuthRobot(tester);
    final boat = BoatRobot(tester);
    final settings = SettingsRobot(tester);
    final maint = MaintenanceRobot(tester);
    final logbook = LogbookRobot(tester);
    final perms = PermissionsRobot(tester);
    final nav = NavRobot(tester);

    // --- As A: read Aurora's share code from the share sheet.
    await boat.openDetail('Aurora');
    final code = await boat.readShareCode();
    expect(code, isNotEmpty);
    // Back to the dashboard: Settings is reached via the shell tabs, and the hub
    // is pushed above them.
    await boat.closeDetail();

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

    // --- B is a viewer: what the owner granted, spelled out on the hub.
    await boat.openDetail('Aurora');
    // Joining by code grants *reading* the documents and nothing else
    // (`boat_members.can_view_documents DEFAULT true`, everything else
    // `DEFAULT false`), and the hub says so area by area instead of letting B
    // find out through a 403.
    await perms.expectWithheld(PermissionsRobot.recordTrips);
    await perms.expectWithheld(PermissionsRobot.manageDocuments);
    await perms.expectWithheld(PermissionsRobot.manageMaintenance);
    await perms.expectWithheld(PermissionsRobot.manageExpenses);
    await perms.expectGranted(PermissionsRobot.viewDocuments);

    // Member view of the whole hub, top to bottom.
    final memberHub = await boat.readDetailLabels();
    expect(memberHub, contains('What you can do'));
    expect(memberHub, contains('Leave shared boat'));
    // Reading documents is granted, so the tile is offered rather than replaced
    // by the padlock (the gate is what decides, and it says yes here).
    expect(memberHub, contains('Documents'));
    // Owner-only: deleting the boat, and granting permissions on it.
    expect(memberHub, isNot(contains('Delete Boat')));
    expect(memberHub, isNot(contains('Crew and permissions')));

    // --- B, blocked area by area. Reopening the hub resets its scroll offset:
    // readDetailLabels leaves it at the bottom, and openTile only scrolls one
    // way.
    await boat.closeDetail();
    await boat.openDetail('Aurora');

    // Maintenance: the padlock and the reason, not a screen that is silently
    // missing its buttons.
    await boat.openTile(
      'Maintenance & expenses',
      perms.blocked(PermissionsRobot.manageMaintenanceBlocked),
    );
    await perms.expectBlocked(PermissionsRobot.manageMaintenanceBlocked);
    expect(find.byTooltip('Add task'), findsNothing);
    expect(find.byTooltip('Record service'), findsNothing);

    // Expenses: same, on the other tab.
    await maint.openExpensesTab();
    await perms.expectBlocked(PermissionsRobot.manageExpensesBlocked);
    expect(find.byTooltip('New expense'), findsNothing);
    await boat.backToHub(find.text('Period total'));
    await boat.closeDetail();

    // Documents: B may read them (J03 left three on Aurora), so the list opens
    // — with the padlock at the top of it and no way to add one. Reached through
    // the dashboard card's own shortcut, which does no gating of its own.
    await tapUntil(
      tester,
      find.text('Documents'),
      perms.blocked(PermissionsRobot.manageDocumentsBlocked),
    );
    expect(find.byTooltip('New Document'), findsNothing);
    await nav.back();
    await pumpUntilFound(tester, find.text('Shared with me'));

    // Trips: no way to start recording at all. This is the one that cost real
    // work — B used to sail a whole trip and lose it to a 403 on save.
    await tapUntil(tester, find.text('Logbook'), find.byTooltip('Statistics'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Start Trip'), findsNothing);
    // The empty-state CTA is the other entry point to the recorder. It only
    // renders while the boat has no trips (J05 gave Aurora one), so this pins
    // the intent rather than exercising it — the recorder itself blocks with
    // the reason if it is ever reached without the permission.
    expect(find.text('Record Trip'), findsNothing);
    await nav.back();
    await pumpUntilFound(tester, find.text('Shared with me'));

    // --- Back to A: grant B the permission to record trips.
    await settings.open();
    await settings.logout();
    await auth.expectLoginScreen();
    await auth.login(e2eEmail, e2ePassword);
    await pumpUntilFound(tester, find.text('Aurora'));

    await boat.openDetail('Aurora');
    await perms.openCrew();
    await perms.expectMember(e2eEmailB);
    // Two, not one: reading documents came with the join, recording trips is
    // what the owner just added.
    await perms.grant(
      e2eEmailB,
      PermissionsRobot.recordTrips,
      expectSummary: '2 permissions',
    );
    await perms.closeCrew();
    await boat.closeDetail();

    // --- B again: the permission is real, on the hub and on the water.
    await settings.open();
    await settings.logout();
    await auth.expectLoginScreen();
    await auth.login(e2eEmailB, e2ePassword);
    await pumpUntilFound(tester, find.text('Aurora'));

    await boat.openDetail('Aurora');
    await perms.expectGranted(PermissionsRobot.recordTrips);
    // Everything else stays withheld — one grant is one grant.
    await perms.expectWithheld(PermissionsRobot.manageExpenses);
    final grantedHub = await boat.readDetailLabels();
    // Still not the owner: granting permissions never becomes B's business.
    expect(grantedHub, isNot(contains('Crew and permissions')));
    await boat.closeDetail();

    // Record and save a real (fake-GPS) trip as the member. Saving is the step
    // that used to answer 403 after the trip was already sailed.
    await tapUntil(tester, find.text('Logbook'), find.byTooltip('Statistics'));
    await pumpUntilFound(tester, find.text('Start Trip'));
    await logbook.startTripViaChecklist();
    await logbook.recordAndSave();
    await pumpUntilFound(tester, find.byTooltip('Statistics'));
    perms.expectNotBlocked(PermissionsRobot.recordTripsBlocked);
    await nav.back();
    await pumpUntilFound(tester, find.text('Shared with me'));

    // --- Back to A: create an expense and split it between both users.
    await settings.open();
    await settings.logout();
    await auth.expectLoginScreen();
    await auth.login(e2eEmail, e2ePassword);
    await pumpUntilFound(tester, find.text('Aurora'));

    // Maintenance & expenses lives on the detail hub (the dashboard card only
    // offers Documents and Logbook now).
    await boat.openDetail('Aurora');
    await boat.openTile(
      'Maintenance & expenses',
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
