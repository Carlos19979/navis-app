import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/logbook/presentation/screens/logbook_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_recording_screen.dart';
import 'package:navis_mobile/features/logbook/presentation/widgets/navigation_hud.dart';
import 'package:navis_mobile/features/profile/presentation/screens/settings_screen.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/pre_trip_checklist_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../helpers/pumping.dart';
import 'nav_robot.dart';
import 'settings_robot.dart';

/// Drives the (now optional) pre-trip safety checklist.
///
/// Starting a trip used to force the checklist on the crew. It now asks once —
/// 'Review checklist' or 'Skip', with 'Remember my choice' — and honours the
/// remembered answer from then on. Settings is the way back for whoever
/// remembered 'Skip', which is also how this robot cleans up after itself: the
/// answer lives in SharedPreferences on the simulator, so a run that left it
/// remembered would silence the question for every later run (and break J05,
/// which reviews).
class ChecklistRobot {
  ChecklistRobot(this.tester);

  final WidgetTester tester;

  /// The prompt, scoped to its dialog: 'Safety checklist' is also the title of
  /// the screen underneath it.
  Finder get prompt => _inDialog(find.text('Review checklist'));

  Finder _inDialog(Finder matching) => find.descendant(
        of: find.byType(AlertDialog),
        matching: matching,
      );

  /// The logbook FAB. The checklist screen's own primary button is also labelled
  /// 'Start Trip', so this one is located by its tooltip.
  Finder get _startTripFab => find.byTooltip('Start Trip');

  Finder get _checklistStartButton =>
      find.widgetWithText(NavisButton, 'Start Trip');

  /// Recording is really running: the HUD renders only while it is.
  Finder get _hud => find.byType(NavigationHud);

  /// Dashboard boat card → Logbook.
  Future<void> openLogbook() async {
    await tapUntil(tester, find.text('Logbook'), _startTripFab);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  Future<void> closeLogbook() async {
    await NavRobot(tester).back();
    await pumpUntilGone(tester, find.byType(LogbookScreen));
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  /// Starts a trip and asserts the question is asked, with both answers and the
  /// option to stop being asked.
  Future<void> startTripExpectingPrompt() async {
    await tapUntil(tester, _startTripFab, prompt);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(
      _inDialog(
        find.text(
          'Do you want to go through the safety checklist before setting sail?',
        ),
      ),
      findsOneWidget,
    );
    expect(_inDialog(find.text('Skip')), findsOneWidget);
    expect(_inDialog(find.text('Remember my choice')), findsOneWidget);
  }

  /// Ticks 'Remember my choice' so the next trip does not ask.
  Future<void> rememberMyChoice() async {
    final tile = _inDialog(find.byType(CheckboxListTile));
    await pumpUntilFound(tester, tile);
    await tester.tap(tile.first);
    await pumpFor(tester, const Duration(milliseconds: 400));
    final box = _inDialog(find.byType(Checkbox));
    expect(tester.widget<Checkbox>(box.first).value, isTrue);
  }

  /// Skip: no checklist at all, straight into a running recording.
  Future<void> skipAndExpectRecording() async {
    await tapUntil(
      tester,
      _inDialog(find.text('Skip')),
      _hud,
      timeout: const Duration(seconds: 25),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    // The checklist route was replaced, not merely skipped past: it is gone,
    // and its items never rendered.
    expect(find.byType(PreTripChecklistScreen), findsNothing);
    expect(_checklistStartButton, findsNothing);
    expect(find.byType(TripRecordingScreen), findsOneWidget);
  }

  /// Review: the checklist opens, with items to tick, and nothing is recording.
  Future<void> reviewAndExpectChecklist() async {
    await tapUntil(
      tester,
      _inDialog(find.text('Review checklist')),
      _checklistStartButton,
      timeout: const Duration(seconds: 15),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(PreTripChecklistScreen), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.byType(TripRecordingScreen), findsNothing);
  }

  /// Backs out of the checklist without sailing.
  Future<void> leaveChecklist() async {
    await NavRobot(tester).back();
    await pumpUntilGone(tester, find.byType(PreTripChecklistScreen));
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  /// Starts a trip expecting the remembered answer to be honoured: no question,
  /// straight to a running recording. Polls both outcomes at once so the
  /// question cannot flash by unnoticed.
  Future<void> startTripExpectingNoPrompt() async {
    await pumpUntilFound(tester, _startTripFab);
    await tester.tap(_startTripFab.first, warnIfMissed: false);
    final end = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        prompt,
        findsNothing,
        reason: 'a remembered answer must not be asked for again',
      );
      if (_hud.evaluate().isNotEmpty) {
        await pumpFor(tester, const Duration(milliseconds: 400));
        return;
      }
    }
    throw TestFailure('trip never started after the remembered Skip');
  }

  /// Leaves the map without saving: 'Cancel trip' → confirm → back on the
  /// logbook. These recordings exist to prove the prompt's branches, not to be
  /// kept.
  Future<void> discardRecording() async {
    final cancel = find.widgetWithText(TextButton, 'Cancel trip');
    await tapUntil(tester, cancel, find.text('Keep going'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    // Title first, destructive action last — both read 'Cancel trip'.
    await tapUntilGone(
      tester,
      _inDialog(find.text('Cancel trip')).last,
      find.byType(AlertDialog),
    );
    await pumpUntilGone(tester, find.byType(TripRecordingScreen));
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  /// Settings → 'Checklist before setting sail' back to asking. Idempotent: one
  /// tap from a remembered 'Skip', two from a remembered 'Review'. Starts and
  /// ends on the Home tab.
  Future<void> restoreAsksEachTime() async {
    final settings = SettingsRobot(tester);
    await settings.open();

    final title = find.descendant(
      of: find.byType(AccountSettingsSections),
      matching: find.text('Checklist before setting sail'),
    );
    await tester.scrollUntilVisible(
      title,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpFor(tester, const Duration(milliseconds: 400));

    final asks = find.text("You'll be asked when a trip starts");
    for (var i = 0; asks.evaluate().isEmpty; i++) {
      if (i == 3) {
        throw TestFailure('could not restore the checklist prompt in Settings');
      }
      final tile =
          find.ancestor(of: title, matching: find.byType(SwitchListTile));
      await tester.tap(tile.first);
      await pumpFor(tester, const Duration(milliseconds: 500));
    }
    expect(asks, findsOneWidget);

    await settings.backToDashboard();
  }
}
