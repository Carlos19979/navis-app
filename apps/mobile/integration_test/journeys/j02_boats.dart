import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/boat_robot.dart';
import '../robots/settings_robot.dart';

/// J02 — Boats & the one-boat cap: create a throwaway boat (with home port) and
/// delete it, then create the run's boat 'Aurora' without a home port (the
/// fixed contract) and assert the cap holds on Free *and* on Pro — paying does
/// not buy a second boat.
///
/// 'Aurora' must survive this journey: J03-J05 and J11 hang their data off it.
void j02Boats() {
  testWidgets('j02 boats: CRUD + one-boat cap on every plan', (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final boat = BoatRobot(tester);
    final settings = SettingsRobot(tester);

    // A throwaway boat, with home port, to cover create + delete.
    await boat.startAddBoat();
    await boat.createBoat(
      name: 'Botavara',
      registration: 'E2E-200',
      homePort: 'Valencia',
    );
    await boat.expectBoatOnDashboard('Botavara');
    // One boat is the cap on Free: no add action, and no paywall selling one.
    await boat.expectNoAddBoatTrigger();
    await boat.deleteBoat('Botavara');
    await pumpUntilGone(tester, find.text('Botavara'));

    // The run's boat, without home port (would 422 before fix/contracts).
    await boat.startAddBoat();
    await boat.createBoat(name: 'Aurora', registration: 'E2E-100');
    await boat.expectBoatOnDashboard('Aurora');

    // Pro does not lift the cap either (dev switcher → real PUT /me/plan).
    // J11 also relies on this flip.
    await settings.open();
    await settings.setPlan('Pro');
    await settings.backToDashboard();
    await boat.expectBoatOnDashboard('Aurora');
    await boat.expectNoAddBoatTrigger();
  });
}
