@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_detail_screen.dart';

import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadTestFonts);

  // The trip is seeded WITHOUT track points on purpose: the map card embeds
  // FlutterMap with live OpenSeaMap tiles, whose fetches fail (and render
  // nondeterministically) in tests. Without a track the screen skips the map
  // card and renders route + stats + crew + notes, all deterministic.
  final trip = makeTrip();

  for (final brightness in Brightness.values) {
    testWidgets('trip detail — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const TripDetailScreen(tripId: 'trip-1'),
        brightness: brightness,
        settle: false,
        overrides: [
          tripProvider.overrideWith((ref, id) async => trip),
        ],
      );
      await expectLater(
        find.byType(TripDetailScreen),
        matchesGoldenFile(goldenPath('trip_detail', brightness)),
      );
    });
  }
}
