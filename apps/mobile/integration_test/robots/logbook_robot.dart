import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/logbook/presentation/screens/trip_recording_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../helpers/pumping.dart';

class LogbookRobot {
  LogbookRobot(this.tester);

  final WidgetTester tester;

  /// From the logbook: FAB → the checklist prompt → the checklist itself →
  /// start the solo trip. Ticks the first checklist item on the way (exercises
  /// the toggle).
  ///
  /// The checklist is no longer a mandatory step: starting a trip asks 'Review
  /// checklist' / 'Skip' first. This robot always reviews — that is the path with
  /// something to assert — and deliberately leaves 'Remember my choice'
  /// unticked, because ticking it persists the answer in SharedPreferences and
  /// every later run on this simulator would skip the prompt (and, having chosen
  /// review, the question) for good.
  Future<void> startTripViaChecklist() async {
    final startTrip = find.widgetWithText(NavisButton, 'Start trip');
    final review = find.text('Review checklist');

    await tapUntil(tester, find.byType(FloatingActionButton), review);
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapUntil(tester, review, startTrip);
    await pumpFor(tester, const Duration(milliseconds: 500));

    final checkbox = find.byType(Checkbox);
    if (checkbox.evaluate().isNotEmpty) {
      await tester.tap(checkbox.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tapUntil(tester, startTrip, find.byType(TripRecordingScreen));
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// Waits until the scripted GPS has produced some distance, then stops and
  /// saves through the completion dialog.
  Future<void> recordAndSave({
    Duration sail = const Duration(seconds: 6),
  }) async {
    // Recording starts automatically (?autostart=true). Let the fake
    // position stream tick.
    await pumpFor(tester, sail);
    // The 'Stop Trip' label sits OUTSIDE the control's GestureDetector —
    // tap the stop icon itself.
    await pumpUntilFound(tester, find.byIcon(Icons.stop));
    await tapUntil(
      tester,
      find.byIcon(Icons.stop),
      find.widgetWithText(NavisButton, 'Save Trip'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    // Saving posts the trip AND the full track before navigating; the track
    // upload can lag the trip POST (queued upload). Single tap — a retap
    // mid-save could double-submit — with instrumented waiting.
    final save = find.widgetWithText(NavisButton, 'Save Trip');
    await pumpUntilFound(tester, save);
    await tester.ensureVisible(save.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(save.first, warnIfMissed: false);
    for (var i = 0; i < 12; i++) {
      await pumpFor(tester, const Duration(seconds: 10));
      final screen = find.byType(TripRecordingScreen).evaluate().length;
      final dialog = save.evaluate().length;
      final snacks = find
          .byType(SnackBar)
          .evaluate()
          .map((e) => ((e.widget as SnackBar).content as Text).data)
          .join('|');
      debugPrint('E2E save+${(i + 1) * 10}s: screen=$screen '
          'dialog=$dialog snack=$snacks');
      if (screen == 0) break;
    }
    await pumpUntilGone(
      tester,
      find.byType(TripRecordingScreen),
      timeout: const Duration(seconds: 5),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  Future<void> openTrip(String textOnCard) async {
    await pumpUntilFound(tester, find.textContaining(textOnCard));
    await tester.tap(find.textContaining(textOnCard).first);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }
}
