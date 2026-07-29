import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/anchor_robot.dart';
import '../robots/boat_robot.dart';
import '../robots/nav_robot.dart';

/// J10 — Anchor watch (Pro, set in J02): open the screen, drop the anchor, let
/// the scripted GPS drift the boat outside the swing circle until the drag
/// alarm fires, silence it, then stop the watch. Disarming at the end is
/// important — the watch is a long-lived GPS stream that must not leak into
/// later journeys.
///
/// The watch is reached from the boat detail hub. Its old entry point was a chip
/// on the boats list that only appeared with exactly one boat; removing that chip
/// would have left this Plus+ feature unreachable, so the hub tile is now the
/// only way in — and this journey is what proves it.
void j10Anchor() {
  testWidgets('j10 anchor watch: arm, drift, alarm, silence, disarm',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final anchor = AnchorRobot(tester);
    final boat = BoatRobot(tester);
    final nav = NavRobot(tester);

    await nav.home();
    await pumpFor(tester, const Duration(milliseconds: 500));

    await boat.openDetail('Aurora');
    await boat.openTile('Anchor watch', AnchorRobot.screenMarker);
    await anchor.dropAnchor();

    // The fake GPS keeps moving NE — the boat drifts past the circle and the
    // banner appears.
    await anchor.waitForDrag();

    // Silence the sound, then fully stop the watch.
    await anchor.silence();
    await anchor.disarm();
    await pumpUntilFound(tester, AnchorRobot.screenMarker);

    // Leave the stack as we found it: anchor screen → hub → dashboard.
    await boat.backToHub(AnchorRobot.screenMarker);
    await boat.closeDetail();
  });
}
