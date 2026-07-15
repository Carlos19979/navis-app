import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';

import 'helpers/bootstrap.dart';
import 'helpers/credentials.dart';
import 'helpers/pumping.dart';
import 'robots/auth_robot.dart';
import 'robots/boat_robot.dart';
import 'robots/settings_robot.dart';

/// Smoke: full user lifecycle against the real local stack.
/// register → create boat → logout → login → delete account.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The glass UI runs looping animations; pumpAndSettle never settles.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('smoke: register → boat → logout → login → delete account',
      (tester) async {
    await bootstrapApp(tester);

    final auth = AuthRobot(tester);
    final boat = BoatRobot(tester);
    final settings = SettingsRobot(tester);

    // Fresh process starts signed out at /login.
    await auth.expectLoginScreen();

    // Register a unique per-run user; confirmations are off locally, so this
    // lands directly on the (empty) boat dashboard.
    await auth.goToRegister();
    await auth.register(e2eEmail, e2ePassword);
    await boat.expectEmptyDashboard();

    // Create a boat through the real form → API → DB.
    await boat.startAddBoat();
    await boat.createBoat(name: 'E2E Smoke', registration: 'E2E-001');
    await boat.expectBoatOnDashboard('E2E Smoke');

    // Log out through Settings and land back on /login.
    await settings.open();
    await settings.logout();
    await auth.expectLoginScreen();

    // Log back in: the boat persisted server-side.
    await auth.login(e2eEmail, e2ePassword);
    await boat.expectBoatOnDashboard('E2E Smoke');

    // Delete the account (GDPR flow) and verify the session is gone and the
    // credentials no longer work.
    await settings.open();
    await settings.deleteAccount();
    await auth.expectLoginScreen();
    expect(supabaseClient.auth.currentSession, isNull);

    await auth.login(e2eEmail, e2ePassword);
    // Login must fail: still on the login screen after the round-trip.
    await pumpFor(tester, const Duration(seconds: 3));
    await auth.expectLoginScreen();
  });
}
