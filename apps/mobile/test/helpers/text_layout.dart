import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixes the viewport to the narrowest phone the app supports (320 logical px,
/// iPhone SE / small Androids). Height stays generous on purpose: the point is
/// horizontal pressure, and a short viewport makes unrelated widgets (the
/// loading shimmer, for one) overflow vertically and pollute the assertion.
///
/// The default `setPhoneSize` uses a 1080-px-wide logical viewport, which is
/// wider than any real phone and therefore hides every truncation and
/// squeeze-the-label bug. Use this whenever the point of the test is layout.
void setNarrowPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Asserts the text found by [finder] got at least the width its widest word
/// needs, i.e. it is neither ellipsized ("Docume…") nor soft-wrapped in the
/// middle of a word ("Mainten/ance").
void expectFullyLaidOut(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final widestWord = paragraph.getMinIntrinsicWidth(double.infinity);
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(widestWord - 0.5),
    reason: 'text was squeezed to ${paragraph.size.width} px, '
        'needs $widestWord px to render without breaking a word',
  );
}

/// Asserts the label found by [text] is offered at least [minShare] of the
/// width of the control found by [control], i.e. the fixed chrome around it
/// (padding, icon, gap) does not eat the room the words need.
///
/// Measures the constraint the label is given rather than the pixels it draws,
/// because widget tests render with a monospaced test font whose glyph widths
/// say nothing about the real ones.
void expectRoomForLabel(
  WidgetTester tester,
  Finder text,
  Finder control, {
  double minShare = 0.6,
}) {
  final available = tester.renderObject<RenderBox>(text).constraints.maxWidth;
  final total = tester.getSize(control).width;
  expect(
    available / total,
    greaterThanOrEqualTo(minShare),
    reason: 'the label is only offered $available of $total px; the chrome '
        'around it leaves too little room and the text truncates',
  );
}
