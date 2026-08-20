@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/screens/today_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';

import '../helpers/helpers.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadTestFonts);

  final boats = [
    makeBoat(),
    makeBoat(
      id: 'boat-2',
      name: 'Sea Runner',
      type: 'motorboat',
      registration: 'ES-BCN-7-5678',
    ),
  ];

  // A boat that needs attention, because that is the interesting screen: the
  // gauge is amber, the coming-up block has rows, and the document row carries
  // a warning. An all-green Today shows none of that.
  final readiness = fakeReadiness(
    score: 72,
    status: ReadinessStatus.attention,
    attention: const [
      ReadinessItem(
        category: 'documents',
        ref: 'insurance_rc',
        status: ReadinessStatus.attention,
        days: 12,
      ),
      ReadinessItem(
        category: 'documents',
        ref: 'radio_cert',
        status: ReadinessStatus.attention,
        days: 25,
      ),
      ReadinessItem(
        category: 'maintenance',
        ref: 'engine_service',
        status: ReadinessStatus.notReady,
        days: -4,
        reason: 'overdue',
      ),
    ],
  );

  // A full-page shot as well as the phone-sized one. Today is a long page and
  // its most interesting parts for review — the other boats and their alerts,
  // the crew rows, the destructive action — sit below the fold, so a 844px
  // viewport captures maybe half of it.
  testWidgets('today, whole page', (tester) async {
    await pumpGolden(
      tester,
      const TodayScreen(),
      brightness: Brightness.light,
      size: const Size(390, 2000),
      settle: false,
      overrides: [
        ...await todayOverrides(
          boats: boats,
          readiness: readiness,
          summary: const DocumentSummary(total: 3, ok: 2, warning: 1),
        ),
        ...planOverrides(),
      ],
    );
    await expectLater(
      find.byType(TodayScreen),
      matchesGoldenFile('goldens/today_full.png'),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('today — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const TodayScreen(),
        brightness: brightness,
        settle: false,
        overrides: [
          ...await todayOverrides(
            boats: boats,
            readiness: readiness,
            summary: const DocumentSummary(total: 3, ok: 2, warning: 1),
          ),
          ...planOverrides(),
        ],
      );
      await expectLater(
        find.byType(TodayScreen),
        matchesGoldenFile(goldenPath('today', brightness)),
      );
    });
  }
}
