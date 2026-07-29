import 'package:flutter_test/flutter_test.dart';

import '../helpers/pumping.dart';

/// Drives the anchor-watch screen. The scripted GPS (see FakeGeolocatorPlatform)
/// keeps moving NE at ~3.4 m/s, so once armed the boat drifts past the default
/// 40 m swing circle within ~15 s and the drag alarm fires.
class AnchorRobot {
  AnchorRobot(this.tester);

  final WidgetTester tester;

  /// Marker for the anchor-watch screen, used by the caller that opens it.
  ///
  /// There is no `open()` here any more: the dashboard chip that used to launch
  /// the watch was removed (it only ever showed with exactly one boat), so the
  /// single entry point is the boat detail hub — `BoatRobot.openTile('Anchor
  /// watch', AnchorRobot.screenMarker)`.
  static Finder get screenMarker => find.text('Drop anchor here');

  /// Drops the anchor at the current fix; the controls switch to the armed
  /// ledger (a 'Stop watch' button appears).
  Future<void> dropAnchor() async {
    await tapUntil(
      tester,
      screenMarker,
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
      screenMarker,
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
}
