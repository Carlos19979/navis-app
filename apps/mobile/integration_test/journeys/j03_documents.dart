import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/document_robot.dart';
import '../robots/nav_robot.dart';

/// J03 — Documents: create one long-dated ('Valid' badge) and one expiring
/// soon ('Critical'), then renew the critical one from its detail screen.
void j03Documents() {
  testWidgets('j03 documents: badges by expiry + renew flow', (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final docs = DocumentRobot(tester);

    // Single-boat dashboard (focus card) → Documents (empty list CTA is the
    // unique marker; the dashboard has its own FAB).
    await tapUntil(
      tester,
      find.text('Documents'),
      find.text('New Document'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    await docs.createDocument(expiresInDays: 200);
    await docs.expectBadge('Valid');

    await docs.createDocument(expiresInDays: 20);
    await docs.expectBadge('Critical');

    // Renew the critical document: card → detail → autorenew action →
    // renew form (defaults push expiry a year out) → save.
    await tapUntil(
      tester,
      find.text('Critical'),
      find.byTooltip('Renew Document'),
    );
    final renewBtn = find.widgetWithText(NavisButton, 'Renew Document');
    await tapUntil(tester, find.byTooltip('Renew Document'), renewBtn);
    await pumpFor(tester, const Duration(milliseconds: 500));
    // Saving the renewal (defaults push expiry a year out) pops back to the
    // document detail.
    await tapUntilGone(tester, renewBtn, renewBtn);
    await pumpFor(tester, const Duration(seconds: 1));

    // Detail → list: both documents now carry the Valid badge.
    final nav = NavRobot(tester);
    for (var i = 0; i < 3 && find.text('Valid').evaluate().length < 2; i++) {
      await nav.back();
      await pumpFor(tester, const Duration(milliseconds: 600));
    }
    await pumpUntilCount(tester, find.text('Valid'), 2);

    // Round #49: a custom-type document (name + extra alert day). The list
    // card shows the custom name as its title.
    await docs.createCustomDocument(name: 'Fishing permit', expiresInDays: 300);
    await pumpUntilFound(tester, find.text('Fishing permit'));
  });
}
