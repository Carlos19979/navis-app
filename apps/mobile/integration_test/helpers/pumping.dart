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
  Duration timeout = const Duration(seconds: 5),
}) async {
  await pumpUntilFound(tester, target);
  for (var attempt = 0; attempt < attempts; attempt++) {
    // A previous (possibly slow) tap may have already produced the result;
    // retapping now could dismiss the very sheet/dialog we just opened.
    if (appears.evaluate().isNotEmpty) return;
    await _prepareTap(tester, target);
    if (appears.evaluate().isNotEmpty) return;
    if (target.evaluate().isEmpty) {
      // Target flickered out (provider rebuild) — wait and retry.
      await pumpFor(tester, const Duration(milliseconds: 500));
      continue;
    }
    await tester.tap(target.first, warnIfMissed: false);
    try {
      await pumpUntilFound(tester, appears, timeout: timeout);
      return;
    } on TestFailure {
      if (attempt == attempts - 1) rethrow;
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  throw TestFailure(
    'tapUntil exhausted $attempts attempts: $target never produced $appears\n'
    'Visible texts: ${_visibleTexts()}',
  );
}

/// Tap that retries until [gone] disappears — for taps whose effect is a
/// dismissal (dialog confirm buttons, closing sheets).
Future<void> tapUntilGone(
  WidgetTester tester,
  Finder target,
  Finder gone, {
  int attempts = 3,
  Duration timeout = const Duration(seconds: 5),
}) async {
  await pumpUntilFound(tester, target);
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (gone.evaluate().isEmpty) return;
    await _prepareTap(tester, target);
    if (gone.evaluate().isEmpty || target.evaluate().isEmpty) return;
    await tester.tap(target.first, warnIfMissed: false);
    try {
      await pumpUntilGone(tester, gone, timeout: timeout);
      return;
    } on TestFailure {
      if (attempt == attempts - 1) rethrow;
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
}

/// Pumps until [finder] matches at least [count] widgets.
Future<void> pumpUntilCount(
  WidgetTester tester,
  Finder finder,
  int count, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().length >= count) return;
  }
  throw TestFailure(
    'pumpUntilCount timed out after ${timeout.inSeconds}s: wanted $count of '
    '$finder\nVisible texts: ${_visibleTexts()}',
  );
}

/// A tap can silently miss when the software keyboard has pushed the target
/// off-viewport: dismiss focus and scroll the target into view first.
Future<void> _prepareTap(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 150));
  try {
    if (target.evaluate().isEmpty) return;
    // Only scroll when the target is actually off-screen: ensureVisible on
    // an already-visible widget inside a TabBarView finds the horizontal
    // PageView as its scrollable ancestor and flips to the other tab.
    final center = tester.getCenter(target.first);
    final view = tester.view;
    final size = view.physicalSize / view.devicePixelRatio;
    final onScreen = center.dx >= 0 &&
        center.dx <= size.width &&
        center.dy >= 0 &&
        center.dy <= size.height;
    if (!onScreen) {
      await tester.ensureVisible(target.first);
      await tester.pump(const Duration(milliseconds: 150));
    }
  } catch (_) {
    // No scrollable ancestor (dialogs, app bars) — tap as-is.
  }
}

/// Scrolls the given scrollable until [item] is built and visible. For lazy
/// lists/slivers where the target widget doesn't exist until scrolled to.
Future<void> scrollTo(
  WidgetTester tester,
  Finder item, {
  Finder? scrollable,
  double delta = 150,
}) async {
  final view = scrollable ?? find.byType(Scrollable);
  await pumpUntilFound(tester, view);
  await tester.scrollUntilVisible(item, delta, scrollable: view.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Fixed-duration pump for fire-and-forget waits (network debounce etc.).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
