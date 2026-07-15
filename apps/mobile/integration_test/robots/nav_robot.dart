import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_bottom_nav.dart';

import '../helpers/pumping.dart';

/// Bottom-tab + chrome navigation. Tab labels are the English l10n values
/// (bootstrap pins locale to `en`).
class NavRobot {
  NavRobot(this.tester);

  final WidgetTester tester;

  /// Scoped to the bottom nav: screen titles and section headers reuse the
  /// same words ('Community', 'Profile'…), so a bare text tap is ambiguous.
  Future<void> goToTab(String label) async {
    final tab = find.descendant(
      of: find.byType(NavisBottomNav),
      matching: find.text(label),
    );
    await pumpUntilFound(tester, tab);
    await tester.tap(tab.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> home() => goToTab('Home');
  Future<void> chart() => goToTab('Map');
  Future<void> weather() => goToTab('Weather');
  Future<void> community() => goToTab('Community');
  Future<void> profile() => goToTab('Profile');

  Future<void> back() async {
    final backIcon = find.byIcon(Icons.arrow_back_ios_new_rounded);
    if (backIcon.evaluate().isNotEmpty) {
      await tester.tap(backIcon.first);
    } else {
      await tester.pageBack();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }
}
