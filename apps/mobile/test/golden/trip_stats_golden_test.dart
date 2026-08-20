@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/screens/trip_stats_screen.dart';

import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

/// The logbook in figures. Worth a baseline of its own: it is the screen with
/// the most numbers on it, so it is where a units or separator bug shows up
/// first — «11.0 kn» instead of «11,0 kt» was found exactly here.
void main() {
  setUpAll(loadTestFonts);

  final trips = [
    makeTrip(
      departureTime: DateTime(2026, 4, 26, 14),
      distanceNm: 29.4,
      engineHours: 3.5,
      fuelConsumedL: 48,
    ),
    makeTrip(
      id: 'trip-2',
      departurePort: 'Barcelona',
      arrivalPort: 'Sitges',
      departureTime: DateTime(2026, 7, 12, 9),
      distanceNm: 18.2,
      maxSpeedKnots: 6.4,
      engineHours: 2,
      fuelConsumedL: 26,
    ),
    makeTrip(
      id: 'trip-3',
      departurePort: 'Port de Soller',
      arrivalPort: 'Sa Calobra',
      departureTime: DateTime(2026, 7, 20, 8),
      distanceNm: 9.7,
      maxSpeedKnots: 5.8,
    ),
  ];

  for (final brightness in Brightness.values) {
    testWidgets('trip stats — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const TripStatsScreen(boatId: 'boat-1'),
        brightness: brightness,
        settle: false,
        overrides: [
          allBoatTripsProvider.overrideWith((ref, id) async => trips),
        ],
      );
      await expectLater(
        find.byType(TripStatsScreen),
        matchesGoldenFile(goldenPath('trip_stats', brightness)),
      );
    });
  }
}
