import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixes the test viewport to a phone-sized screen (1080x1920, dpr 1.0) and
/// registers a teardown that restores the defaults.
void setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps enough frames for async providers and animation init without
/// pumpAndSettle (which never completes due to flutter_animate's repeating
/// animations).
Future<void> pumpScreen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Disposes the widget tree and drains any remaining timers so tests with
/// never-completing futures or looping animations end cleanly.
Future<void> drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Asserts a [SnackBar] containing [text] is currently shown.
void expectSnackbar(WidgetTester tester, String text) {
  expect(find.widgetWithText(SnackBar, text), findsOneWidget);
}

/// Pumps [frames] frames of 100 ms.
///
/// [pumpScreen] pumps two, which is enough for a screen whose data comes from
/// one provider. It is not enough for a screen built from *chained* providers —
/// Today resolves its boats, then mounts the children that ask for readiness
/// and the document summary — because each link needs its own frame before the
/// next one is even in the tree. Not `pumpAndSettle`: flutter_animate's bounded
/// loops mean settling can take seconds of fake time, and a stalled request
/// would hang forever.
Future<void> pumpFrames(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [scrollable] top to bottom and returns every [Text] seen on the way.
///
/// A long screen built from slivers or a `ListView` disposes what scrolls off,
/// so "this row exists and that one does not" cannot be asserted from a single
/// screenful.
Future<Set<String>> scrollAndCollectText(
  WidgetTester tester,
  Finder scrollable, {
  int drags = 10,
}) async {
  final seen = <String>{};
  void collect() {
    for (final element in find.byType(Text).evaluate()) {
      final data = (element.widget as Text).data?.trim();
      if (data != null && data.isNotEmpty) seen.add(data);
    }
  }

  await pumpFrames(tester, frames: 6);
  collect();
  for (var i = 0; i < drags; i++) {
    await tester.drag(scrollable, const Offset(0, -400), warnIfMissed: false);
    await pumpFrames(tester, frames: 3);
    collect();
  }
  return seen;
}

/// Drags the scrollable under [scrollableKey] until [target] is on screen.
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder target,
  Key scrollableKey, {
  int drags = 12,
}) async {
  for (var i = 0; i < drags; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.drag(
      find.byKey(scrollableKey),
      const Offset(0, -400),
      warnIfMissed: false,
    );
    await pumpFrames(tester, frames: 3);
  }
}
