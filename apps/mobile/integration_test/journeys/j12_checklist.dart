import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/checklist_robot.dart';
import '../robots/nav_robot.dart';

/// J12 — The pre-trip checklist is a recommendation now, not a gate.
///
/// Before build 5 every trip started with the full safety checklist, whether the
/// crew wanted it or not. Starting a trip now asks once — 'Review checklist' or
/// 'Skip' — with 'Remember my choice' for anyone tired of answering. All three
/// branches are walked here: the question, Skip sailing without a checklist,
/// Review opening it, and a remembered answer replacing the question for good.
///
/// The remembered answer is persisted on the simulator, so this journey brackets
/// itself with the Settings reset that is the user's way back — otherwise it
/// would silently disarm J05 (which reviews) on every later run.
void j12Checklist() {
  testWidgets(
      'j12 checklist: asks, Skip records, Review opens, remember sticks',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final nav = NavRobot(tester);
    final checklist = ChecklistRobot(tester);

    await nav.home();
    // Known starting point: asking each time (an earlier crashed run on this
    // simulator could have left an answer remembered).
    await checklist.restoreAsksEachTime();
    await checklist.openLogbook();

    // It asks, instead of dragging everyone through the list.
    await checklist.startTripExpectingPrompt();

    // Skip sails immediately: no checklist, recording already running.
    await checklist.skipAndExpectRecording();
    await checklist.discardRecording();

    // Review still opens the checklist, with its items to tick.
    await checklist.startTripExpectingPrompt();
    await checklist.reviewAndExpectChecklist();
    await checklist.leaveChecklist();

    // Remembering the answer is what stops the question.
    await checklist.startTripExpectingPrompt();
    await checklist.rememberMyChoice();
    await checklist.skipAndExpectRecording();
    await checklist.discardRecording();

    // Next trip: no question at all, straight to recording.
    await checklist.startTripExpectingNoPrompt();
    await checklist.discardRecording();

    // Hand the simulator back asking again — and prove Settings can undo a
    // remembered 'Skip', which is the only way back to the checklist.
    await checklist.closeLogbook();
    await checklist.restoreAsksEachTime();
  });
}
