@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/screens/readiness_screen.dart';

import 'golden_harness.dart';

Readiness _sample() => const Readiness(
      score: 72,
      status: ReadinessStatus.attention,
      full: true,
      categories: [
        ReadinessCategory(
          key: 'documents',
          status: ReadinessStatus.attention,
          total: 5,
          expired: 0,
          critical: 1,
          warning: 1,
          ok: 3,
        ),
        ReadinessCategory(
          key: 'safety_gear',
          status: ReadinessStatus.ready,
          total: 4,
          expired: 0,
          critical: 0,
          warning: 0,
          ok: 4,
        ),
        ReadinessCategory(
          key: 'maintenance',
          status: ReadinessStatus.ready,
          total: 1,
          expired: 0,
          critical: 0,
          warning: 0,
          ok: 1,
        ),
      ],
      attention: [
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
      ],
    );

void main() {
  setUpAll(loadTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('readiness screen — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const ReadinessScreen(boatId: 'boat-1'),
        brightness: brightness,
        overrides: [
          boatReadinessProvider('boat-1')
              .overrideWith((ref) async => _sample()),
        ],
      );
      await expectLater(
        find.byType(ReadinessScreen),
        matchesGoldenFile(goldenPath('readiness', brightness)),
      );
    });
  }
}
