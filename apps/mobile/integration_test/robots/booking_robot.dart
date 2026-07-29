import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

import '../helpers/pumping.dart';

/// Drives the bookings screen (Pro, shared-boat coordination).
///
/// Bookings are ranges now — departure date+time to arrival date+time — created
/// through **one** entry point: the screen's FAB. The 'Book this day' button on
/// the calendar is gone; the calendar is read-only and only preselects the day
/// the form opens on. That is why this robot never touches the grid.
///
/// The form opens on a valid default range (today 09:00 → 18:00), so a booking
/// needs no picker interaction at all — which also means two consecutive
/// bookings overlap each other, exercising the API's 409 + 'Book anyway'.
class BookingRobot {
  BookingRobot(this.tester);

  final WidgetTester tester;

  /// Marker for the bookings screen: the FAB, the single way in.
  static Finder get screenMarker => find.byTooltip('Book');

  /// The range form is on screen. Its hint line is the one string that belongs
  /// to the sheet alone — 'Book' is both the FAB label and the sheet title.
  Finder get _form =>
      find.text('From departure to arrival. Same day for a day out.');

  /// Creates a booking on the default range with [purpose].
  Future<void> create(String purpose) async {
    await _openForm(purpose);
    await tapUntilGone(tester, _saveButton, _form);
    await pumpFor(tester, const Duration(seconds: 1));
    await pumpUntilFound(tester, find.textContaining(purpose));
  }

  /// Creates a booking that collides with an existing one: the API answers 409,
  /// the form asks, and 'Book anyway' forces it through.
  Future<void> createExpectingOverlap(String purpose) async {
    await _openForm(purpose);
    await tapUntil(tester, _saveButton, find.text('Book anyway'));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapUntilGone(tester, find.text('Book anyway'), _form);
    await pumpFor(tester, const Duration(seconds: 1));
    await pumpUntilFound(tester, find.textContaining(purpose));
  }

  Future<void> _openForm(String purpose) async {
    await pumpUntilGone(
      tester,
      find.byType(SnackBar),
      timeout: const Duration(seconds: 8),
    );
    await tapUntil(tester, screenMarker, _form);
    await pumpFor(tester, const Duration(milliseconds: 500));
    final field = find.descendant(
      of: find.widgetWithText(NavisTextField, 'Purpose (optional)'),
      matching: find.byType(TextField),
    );
    await pumpUntilFound(tester, field);
    await enterTextChecked(tester, field, purpose);
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(tester, const Duration(milliseconds: 300));
  }

  Finder get _saveButton => find.widgetWithText(NavisButton, 'Save');
}
