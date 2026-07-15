import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:navis_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../helpers/pumping.dart';

class AuthRobot {
  AuthRobot(this.tester);

  final WidgetTester tester;

  Future<void> expectLoginScreen() =>
      pumpUntilFound(tester, find.widgetWithText(NavisButton, 'Log In'));

  Future<void> goToRegister() async {
    await tapUntil(
      tester,
      find.textContaining("Don't have an account?"),
      find.text('Create Account'),
    );
    // Let the route transition finish: while both auth screens are in the
    // tree, unscoped field indices point at the outgoing screen.
    await pumpFor(tester, const Duration(milliseconds: 800));
  }

  Future<void> register(String email, String password) async {
    final fields = find.descendant(
      of: find.byType(RegisterScreen),
      matching: find.byType(TextFormField),
    );
    await pumpUntilFound(tester, fields);
    await enterTextChecked(tester, fields.at(0), email);
    await enterTextChecked(tester, fields.at(1), password);
    await enterTextChecked(tester, fields.at(2), password);
    await tester.tap(find.widgetWithText(NavisButton, 'Register'));
  }

  Future<void> login(String email, String password) async {
    await expectLoginScreen();
    await pumpFor(tester, const Duration(milliseconds: 800));
    final fields = find.descendant(
      of: find.byType(LoginScreen),
      matching: find.byType(TextFormField),
    );
    await pumpUntilFound(tester, fields);
    await enterTextChecked(tester, fields.at(0), email);
    await enterTextChecked(tester, fields.at(1), password);
    await tester.tap(find.widgetWithText(NavisButton, 'Log In'));
  }
}
