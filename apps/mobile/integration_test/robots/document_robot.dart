import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../helpers/pumping.dart';

class DocumentRobot {
  DocumentRobot(this.tester);

  final WidgetTester tester;

  /// Creates a document from the list screen via FAB. Only the expiry date is
  /// varied — the type dropdown keeps its default ('Registration').
  Future<void> createDocument({required int expiresInDays}) async {
    // 'Expiry Date' is the form-only marker; the list's empty-state CTA also
    // says 'New Document', which would satisfy a title-based finder early.
    await tapUntil(
      tester,
      find.byType(FloatingActionButton),
      find.textContaining('Expiry Date'),
    );
    await pumpFor(tester, const Duration(milliseconds: 600));
    await _pickExpiryDate(daysFromNow: expiresInDays);
    final save = find.widgetWithText(NavisButton, 'Save');
    await tester.ensureVisible(save.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tapUntilGone(tester, save, find.text('New Document'));
  }

  /// Opens the date picker from the expiry field, switches it to input mode
  /// (typing beats navigating N months) and confirms.
  Future<void> _pickExpiryDate({required int daysFromNow}) async {
    final expiryField = find.textContaining('Expiry Date');
    await pumpUntilFound(tester, expiryField);
    await tapUntil(tester, expiryField, find.byType(DatePickerDialog));
    await pumpFor(tester, const Duration(milliseconds: 400));

    // Switch to input mode; icon differs across Material versions. Scope to
    // the dialog — the custom-name field's prefix is also an edit icon.
    for (final icon in [Icons.edit_outlined, Icons.edit]) {
      final f = find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byIcon(icon),
      );
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await pumpFor(tester, const Duration(milliseconds: 400));
        break;
      }
    }
    final date = DateTime.now().add(Duration(days: daysFromNow));
    final text =
        '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    final input = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    );
    await pumpUntilFound(tester, input);
    await tester.enterText(input.first, text);
    await tester.pump(const Duration(milliseconds: 200));
    await tapUntilGone(
      tester,
      find.text('OK'),
      find.byType(DatePickerDialog),
    );
  }

  /// Creates a custom-type document: selects 'Other (custom)', names it,
  /// adds an extra alert-day threshold, then saves (round #49).
  Future<void> createCustomDocument({
    required String name,
    required int expiresInDays,
    int extraAlertDay = 15,
  }) async {
    await tapUntil(
      tester,
      find.byType(FloatingActionButton),
      find.textContaining('Expiry Date'),
    );
    await pumpFor(tester, const Duration(milliseconds: 600));

    // Pick the custom type from the dropdown. NOTE: the `appears` marker must
    // be a plain finder — a `.last`/`.first` finder throws on empty evaluate.
    await tapUntil(
      tester,
      find.byType(DropdownButtonFormField<String>),
      find.text('Other (custom)'),
    );
    await tester.tap(find.text('Other (custom)').last);
    await pumpFor(tester, const Duration(milliseconds: 400));

    // Name it (required for custom).
    final nameField =
        find.widgetWithText(TextFormField, 'Custom document name');
    await pumpUntilFound(tester, nameField);
    await enterTextChecked(tester, nameField, name);

    // Add an extra alert-day threshold via its chip.
    final chip = find.widgetWithText(FilterChip, '$extraAlertDay days');
    if (chip.evaluate().isNotEmpty) {
      await tester.tap(chip.first);
      await pumpFor(tester, const Duration(milliseconds: 300));
    }

    await _pickExpiryDate(daysFromNow: expiresInDays);
    final save = find.widgetWithText(NavisButton, 'Save');
    await tester.ensureVisible(save.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tapUntilGone(tester, save, find.text('New Document'));
  }

  Future<void> expectBadge(String label) =>
      pumpUntilFound(tester, find.text(label));
}
