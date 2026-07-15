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
