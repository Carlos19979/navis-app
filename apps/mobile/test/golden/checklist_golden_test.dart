@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/config/checklist_preference.dart';
import 'package:navis_mobile/features/regattas/presentation/screens/pre_trip_checklist_screen.dart';

import 'golden_harness.dart';

/// The last screen before casting off, so it is read standing up on a moving
/// deck: the baseline is here to keep the rows at a thumb's size and the
/// progress line legible.
class _AlwaysReview extends Notifier<PreTripChecklistMode>
    implements PreTripChecklistModeNotifier {
  @override
  PreTripChecklistMode build() => PreTripChecklistMode.review;

  @override
  void set(PreTripChecklistMode mode) {}
}

void main() {
  setUpAll(loadTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('pre-trip checklist — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const PreTripChecklistScreen(boatId: 'boat-1'),
        brightness: brightness,
        settle: false,
        overrides: [
          // «Always review», so the shot is the checklist and not the prompt
          // that asks whether to show it.
          preTripChecklistModeProvider.overrideWith(_AlwaysReview.new),
        ],
      );
      await expectLater(
        find.byType(PreTripChecklistScreen),
        matchesGoldenFile(goldenPath('checklist', brightness)),
      );
    });
  }
}
