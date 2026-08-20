@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';

import '../helpers/helpers.dart';
import 'golden_harness.dart';

/// **Today with three boats** — the state the design was asked about, and the
/// one that has already produced two flow bugs.
///
/// The rule the redesign settled on: Today is about *one* boat, the active one.
/// The others live behind the name in the header, and the only thing they are
/// allowed to do to this screen is put a dot on the chevron when one of them
/// needs attention. Everything else — their names, their status — is inside the
/// sheet, one tap away.
///
/// So there are two shots: the page (dot, no clutter) and the sheet open (all
/// three with their status, plus the two ways to get a fourth).
void main() {
  setUpAll(loadTestFonts);

  final boats = [
    makeBoat(photoUrl: 'https://example.test/luna.jpg'),
    makeBoat(id: 'boat-2', name: 'Sea Runner', type: 'motorboat'),
    makeBoat(id: 'boat-3', name: 'Marea'),
  ];

  /// The active boat is in order; one of the *others* has an expired document.
  /// That is what the dot is for, and it is the only case where a boat you are
  /// not looking at is allowed to interrupt.
  const summaries = {
    'boat-1': DocumentSummary(total: 4, ok: 4),
    'boat-2': DocumentSummary(total: 3, ok: 2, expired: 1),
    'boat-3': DocumentSummary(total: 2, ok: 2),
  };

  final readiness = fakeReadiness(score: 92, attention: []);

  testWidgets('today with three boats', (tester) async {
    await pumpGolden(
      tester,
      const TodayScreen(),
      brightness: Brightness.light,
      settle: false,
      overrides: [
        ...await todayOverrides(
          boats: boats,
          readiness: readiness,
          summaries: summaries,
        ),
        ...planOverrides(pro: true),
      ],
    );
    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/today_three_boats.png'),
    );
  });

  testWidgets('the boat switcher, open', (tester) async {
    await pumpGolden(
      tester,
      const TodayScreen(),
      brightness: Brightness.light,
      settle: false,
      overrides: [
        ...await todayOverrides(
          boats: boats,
          readiness: readiness,
          summaries: summaries,
        ),
        ...planOverrides(pro: true),
      ],
    );

    await tester.tap(find.byIcon(Icons.expand_more_rounded).first);
    await pumpGoldenFrames(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/today_switcher_sheet.png'),
    );
  });
}
