import 'package:flutter_test/flutter_test.dart';

import '../helpers/pumping.dart';

/// Drives the anchor-watch screen. The scripted GPS (see FakeGeolocatorPlatform)
/// keeps moving NE at ~3.4 m/s, so once armed the boat drifts past the default
/// 40 m swing circle within ~15 s and the drag alarm fires.
class AnchorRobot {
  AnchorRobot(this.tester);

  final WidgetTester tester;

  /// Opens the anchor watch from the focus dashboard (Pro button).
  Future<void> open() async {
    await tapUntil(
      tester,
      find.text('Anchor watch'),
      find.text('Drop anchor here'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  /// Drops the anchor at the current fix; the controls switch to the armed
  /// ledger (a 'Stop watch' button appears).
  Future<void> dropAnchor() async {
    await tapUntil(
      tester,
      find.text('Drop anchor here'),
      find.text('Stop watch'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  /// Waits for the boat to drift outside the circle and the drag banner to show.
  Future<void> waitForDrag() async {
    await pumpUntilFound(
      tester,
      find.text('Dragging anchor!'),
      timeout: const Duration(seconds: 30),
    );
  }

  Future<void> silence() async {
    await tester.tap(find.text('Silence').first, warnIfMissed: false);
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  /// Stops the watch — the control panel returns to the drop CTA.
  Future<void> disarm() async {
    await tapUntil(
      tester,
      find.text('Stop watch'),
      find.text('Drop anchor here'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
}
