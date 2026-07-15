import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/credentials.dart';
import '../helpers/pumping.dart';
import '../robots/auth_robot.dart';
import '../robots/boat_robot.dart';

/// J01 — Auth: bad credentials show an inline error; registering the per-run
/// user lands on the empty dashboard.
void j01Auth() {
  testWidgets('j01 auth: bad login errors, register lands on dashboard',
      (tester) async {
    await bootstrapApp(tester);
    final auth = AuthRobot(tester);
    final boat = BoatRobot(tester);

    await auth.expectLoginScreen();

    // Wrong credentials → inline error box (red icon), still on login.
    await auth.login('nobody@navis.local', 'wrong-password');
    await pumpUntilFound(tester, find.byIcon(Icons.error_outline));
    await auth.expectLoginScreen();

    // Register the run user → straight to the (empty) dashboard.
    await auth.goToRegister();
    await auth.register(e2eEmail, e2ePassword);
    await boat.expectEmptyDashboard();
  });
}
