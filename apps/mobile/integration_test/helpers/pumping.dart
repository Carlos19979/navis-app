import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Polling pumps. `pumpAndSettle` is unusable here: the glass UI runs looping
/// flutter_animate shimmer/glow animations that never settle.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure(
    'pumpUntilFound timed out after ${timeout.inSeconds}s: $finder\n'
    'Visible texts: ${_visibleTexts()}',
  );
}

/// All Text/RichText strings currently on screen — the failure equivalent of
/// a screenshot, so a timeout says which screen the app was stuck on.
List<String> _visibleTexts() {
  return find
      .byType(RichText)
      .evaluate()
      .map((e) => (e.widget as RichText).text.toPlainText().trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure(
    'pumpUntilGone timed out after ${timeout.inSeconds}s: $finder\n'
    'Visible texts: ${_visibleTexts()}',
  );
}

/// Text entry that verifies the controller actually received the text and
/// retries. Plain `enterText` can silently miss while a route transition or
/// entrance animation is still moving the field.
Future<void> enterTextChecked(
  WidgetTester tester,
  Finder field,
  String text,
) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    await tester.ensureVisible(field.first);
    await tester.tap(field.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(field.first, text);
    await tester.pump(const Duration(milliseconds: 150));
    final editable = find.descendant(
      of: field.first,
      matching: find.byType(EditableText),
    );
    if (editable.evaluate().isNotEmpty &&
        tester.widget<EditableText>(editable.first).controller.text == text) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  throw TestFailure('enterTextChecked: could not enter "$text" into $field');
}

/// Tap that retries until [appears] shows up. Right after a scroll (ballistic
/// still settling) or during route transitions the first tap can be swallowed
/// by the gesture arena; asserting the effect is the only reliable signal.
Future<void> tapUntil(
  WidgetTester tester,
  Finder target,
  Finder appears, {
  int attempts = 3,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.tap(target.first, warnIfMissed: false);
    try {
      await pumpUntilFound(
        tester,
        appears,
        timeout: const Duration(seconds: 5),
      );
      return;
    } on TestFailure {
      if (attempt == attempts - 1) rethrow;
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
}

/// Tap that retries until [gone] disappears — for taps whose effect is a
/// dismissal (dialog confirm buttons, closing sheets).
Future<void> tapUntilGone(
  WidgetTester tester,
  Finder target,
  Finder gone, {
  int attempts = 3,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.tap(target.first, warnIfMissed: false);
    try {
      await pumpUntilGone(tester, gone, timeout: const Duration(seconds: 5));
      return;
    } on TestFailure {
      if (attempt == attempts - 1) rethrow;
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
}

/// Fixed-duration pump for fire-and-forget waits (network debounce etc.).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
