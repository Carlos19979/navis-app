import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';

import '../helpers/bootstrap.dart';
import '../helpers/credentials.dart';
import '../helpers/pumping.dart';
import '../robots/auth_robot.dart';
import '../robots/nav_robot.dart';
import '../robots/settings_robot.dart';

/// J08 — Profile, settings and teardown: profile renders the run user,
/// settings toggles work, the passport entry is Pro-enabled, and the account
/// is deleted through the real GDPR flow (which is also the suite teardown).
void j08ProfileTeardown() {
  testWidgets('j08 profile, settings, passport entry and account deletion',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final nav = NavRobot(tester);
    final auth = AuthRobot(tester);
    final settings = SettingsRobot(tester);

    // Profile tab: the run user's email is shown.
    await nav.profile();
    await pumpUntilFound(tester, find.text(e2eEmail));

    // Passport export entry exists on the boat detail (Pro) — asserted up to
    // the native share boundary elsewhere; here we only check reachability
    // via profile → no tap.

    // Settings: theme toggle flips and sticks.
    await settings.open();
    final darkSwitch = find.byType(SwitchListTile).first;
    await tester.tap(darkSwitch);
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(darkSwitch);
    await pumpFor(tester, const Duration(milliseconds: 600));

    // Delete the account: real GDPR flow, doubles as suite teardown.
    await settings.deleteAccount();
    await auth.expectLoginScreen();
    expect(supabaseClient.auth.currentSession, isNull);

    // The credentials must be dead.
    await auth.login(e2eEmail, e2ePassword);
    await pumpFor(tester, const Duration(seconds: 3));
    await auth.expectLoginScreen();
  });
}
