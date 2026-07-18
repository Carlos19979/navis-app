import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/anchor_robot.dart';
import '../robots/nav_robot.dart';

/// J10 — Anchor watch (Pro, set in J02): open the screen, drop the anchor, let
/// the scripted GPS drift the boat outside the swing circle until the drag
/// alarm fires, silence it, then stop the watch. Disarming at the end is
/// important — the watch is a long-lived GPS stream that must not leak into
/// later journeys.
void j10Anchor() {
  testWidgets('j10 anchor watch: arm, drift, alarm, silence, disarm',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final anchor = AnchorRobot(tester);
    final nav = NavRobot(tester);

    await nav.home();
    await pumpFor(tester, const Duration(milliseconds: 500));

    await anchor.open();
    await anchor.dropAnchor();

    // The fake GPS keeps moving NE — the boat drifts past the circle and the
    // banner appears.
    await anchor.waitForDrag();

    // Silence the sound, then fully stop the watch.
    await anchor.silence();
    await anchor.disarm();
    await pumpUntilFound(tester, find.text('Drop anchor here'));

    await nav.back();
  });
}
