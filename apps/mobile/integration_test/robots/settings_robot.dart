import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/profile/presentation/screens/settings_screen.dart';

import '../helpers/pumping.dart';
import 'nav_robot.dart';

class SettingsRobot {
  SettingsRobot(this.tester);

  final WidgetTester tester;

  /// Profile tab → Settings entry.
  Future<void> open() async {
    final nav = NavRobot(tester);
    await nav.profile();
    await pumpUntilFound(tester, find.text('Settings'));
    await tester.tap(find.text('Settings').last);
    await pumpUntilFound(tester, find.text('Log Out'));
  }

  /// Settings is a lazy ListView pushed on top of the shell: earlier routes
  /// stay in the tree, so both the scrollable and the items must be scoped to
  /// SettingsScreen or the scroll/tap lands on the screen behind.
  Finder _inSettings(Finder matching) => find.descendant(
        of: find.byType(SettingsScreen),
        matching: matching,
      );

  Future<void> _scrollTo(Finder item) async {
    // No `.first` here: a first-finder throws while the lazy ListView hasn't
    // built the item yet; scrollUntilVisible needs a finder that can match 0.
    await tester.scrollUntilVisible(
      item,
      150,
      scrollable: _inSettings(find.byType(Scrollable)).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Dialog-scoped finder: the label also exists on the screen behind the
  /// modal barrier; tapping that one dismisses the dialog instead.
  Finder _inDialog(Finder matching) => find.descendant(
        of: find.byType(AlertDialog),
        matching: matching,
      );

  /// Pops Settings and returns to the Home tab.
  Future<void> backToDashboard() async {
    final nav = NavRobot(tester);
    await nav.back();
    await nav.home();
  }

  /// Debug-only dev plan switcher (top card in Settings). Sets the plan via
  /// the real PUT /me/plan endpoint.
  Future<void> setPlan(String label) async {
    await pumpUntilFound(tester, find.text('PLAN (PRUEBAS)'));
    await tester.tap(_inSettings(find.text(label)).first);
    await pumpFor(tester, const Duration(seconds: 1));
  }

  Future<void> logout() async {
    await _scrollTo(_inSettings(find.text('Log Out')));
    await tapUntil(
      tester,
      _inSettings(find.text('Log Out')),
      find.text('Cancel'),
    );
    // Let the dialog entrance animation finish before touching its actions.
    await pumpFor(tester, const Duration(milliseconds: 400));
    // Within the dialog the title comes first, the destructive action last.
    await tapUntilGone(
      tester,
      _inDialog(find.text('Log Out')).last,
      find.byType(AlertDialog),
    );
  }

  /// Full GDPR delete-account flow: warning dialog → type-to-confirm.
  Future<void> deleteAccount() async {
    final entry = _inSettings(find.text('Delete account'));
    await _scrollTo(entry);

    // Step 1: warning dialog.
    await tapUntil(tester, entry, _inDialog(find.text('Delete')));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapUntil(
      tester,
      _inDialog(find.text('Delete')).last,
      _inDialog(find.byType(TextField)),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));

    // Step 2: type-to-confirm.
    await tester.enterText(_inDialog(find.byType(TextField)).last, 'DELETE');
    await tester.pump(const Duration(milliseconds: 200));
    await tapUntilGone(
      tester,
      _inDialog(find.text('Delete')).last,
      find.byType(AlertDialog),
    );
  }
}
