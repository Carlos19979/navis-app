import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../helpers/pumping.dart';

class BoatRobot {
  BoatRobot(this.tester);

  final WidgetTester tester;

  /// Empty-state CTA on a fresh account; also asserts the dashboard loaded.
  Future<void> expectEmptyDashboard() =>
      pumpUntilFound(tester, find.text('Add Boat'));

  Future<void> startAddBoat() async {
    await pumpUntilFound(tester, find.text('Add Boat'));
    await tester.tap(find.text('Add Boat').first);
    await pumpUntilFound(tester, find.text('New Boat'));
  }

  /// Fills the required fields (type dropdown keeps its default) and submits.
  /// Home port is genuinely optional (nullable end to end since migration
  /// 00033) — pass [homePort] to also exercise the with-port path.
  Future<void> createBoat({
    required String name,
    required String registration,
    String length = '9.5',
    String? homePort,
  }) async {
    await _enterField('Boat Name', name);
    await _enterField('Registration Number', registration);
    await _enterField('Length (m)', length);
    if (homePort != null) {
      await _enterField('Home Port (optional)', homePort);
    }
    // Dismiss the keyboard so the submit button is tappable, then require the
    // form to actually go away — a missed tap or validation error would
    // otherwise pass silently (field values don't show up as Text widgets).
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 300));
    final submit = find.widgetWithText(NavisButton, 'Create Boat');
    // Retry the tap: a submit that lands shows either navigation (form gone)
    // or an error/validation message; a missed tap shows neither.
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.ensureVisible(submit.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(submit.first);
      try {
        await pumpUntilGone(
          tester,
          find.text('New Boat'),
          timeout: const Duration(seconds: 10),
        );
        return;
      } on TestFailure {
        if (attempt == 2) rethrow;
      }
    }
  }

  Future<void> expectBoatOnDashboard(String name) =>
      pumpUntilFound(tester, find.text(name));

  Future<void> _enterField(String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await pumpUntilFound(tester, field);
    await enterTextChecked(tester, field, value);
  }
}
