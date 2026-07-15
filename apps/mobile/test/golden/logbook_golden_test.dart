@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/logbook_screen.dart';

import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadTestFonts);

  final trips = [
    makeTrip(),
    makeTrip(
      id: 'trip-2',
      departurePort: 'Barcelona',
      arrivalPort: 'Sitges',
      distanceNm: 18.2,
      maxSpeedKnots: 6.4,
    ),
    makeTrip(
      id: 'trip-3',
      departurePort: 'Port de Soller',
      arrivalPort: 'Sa Calobra',
      distanceNm: 9.7,
      maxSpeedKnots: 5.8,
    ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('logbook — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const LogbookScreen(boatId: 'boat-1'),
        brightness: brightness,
        settle: false,
        overrides: [
          boatProvider.overrideWith((ref, id) async => makeBoat(id: id)),
          boatTripsProvider.overrideWith((ref, id) async => trips),
          tripStatsProvider.overrideWith((ref, trips) => makeTripStats()),
        ],
      );
      await expectLater(
        find.byType(LogbookScreen),
        matchesGoldenFile(goldenPath('logbook', brightness)),
      );
    });
  }
}
