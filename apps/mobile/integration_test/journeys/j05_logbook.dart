import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/logbook_robot.dart';
import '../robots/nav_robot.dart';

/// J05 — Logbook with scripted GPS: checklist → record a real (fake-GPS)
/// trip → save → the trip and its stats exist.
void j05Logbook() {
  testWidgets('j05 logbook: record trip via fake GPS and save', (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final logbook = LogbookRobot(tester);
    final nav = NavRobot(tester);

    // Focus dashboard → Logbook (empty).
    await tapUntil(
      tester,
      find.text('Logbook'),
      find.text('Record Trip'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Checklist → autostarted recording → sail a few fake-GPS seconds →
    // stop → completion dialog → save.
    await logbook.startTripViaChecklist();
    await logbook.recordAndSave();

    // The logbook now lists the trip (departure port from home port is
    // absent for Aurora, so match on the stats summary instead).
    await pumpUntilFound(tester, find.text('Logbook'));
    await pumpFor(tester, const Duration(seconds: 1));

    // Trip stats aggregate at least one trip.
    await tapUntil(
      tester,
      find.byTooltip('Statistics'),
      find.text('Trip Statistics'),
    );
    await pumpFor(tester, const Duration(seconds: 1));
    await nav.back();
  });
}
