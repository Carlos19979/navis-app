import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/boat_robot.dart';
import '../robots/settings_robot.dart';

/// J02 — Boats & plan gate: create the run's boat (no home port — the fixed
/// contract), hit the Free 1-boat limit → paywall renders, flip to Pro via
/// the dev switcher, add + delete a second boat.
void j02Boats() {
  testWidgets('j02 boats: CRUD + paywall at Free limit + Pro flip',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final boat = BoatRobot(tester);
    final settings = SettingsRobot(tester);

    // Boat #1 without home port (would 422 before fix/contracts).
    await boat.startAddBoat();
    await boat.createBoat(name: 'Aurora', registration: 'E2E-100');
    await boat.expectBoatOnDashboard('Aurora');

    // Free limit: adding a second boat must show the paywall.
    await boat.startAddBoatExpectingPaywall();
    await boat.dismissPaywall();

    // Flip to Pro through Settings (dev switcher → real PUT /me/plan).
    await settings.open();
    await settings.setPlan('Pro');
    await settings.backToDashboard();

    // Now a second boat is allowed; then delete it via edit form.
    await boat.startAddBoat();
    await boat.createBoat(
      name: 'Botavara',
      registration: 'E2E-200',
      homePort: 'Valencia',
    );
    await boat.expectBoatOnDashboard('Botavara');
    await boat.deleteBoat('Botavara');
    await pumpUntilGone(tester, find.text('Botavara'));
  });
}
