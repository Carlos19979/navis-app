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

    // Switch to input mode; icon differs across Material versions.
    for (final icon in [Icons.edit_outlined, Icons.edit]) {
      final f = find.byIcon(icon);
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

  Future<void> expectBadge(String label) =>
      pumpUntilFound(tester, find.text(label));
}
