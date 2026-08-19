@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/features/cost/presentation/screens/cost_analytics_screen.dart';

import 'golden_harness.dart';

/// A season on a Mediterranean sailboat: a berth and insurance every year, fuel
/// and maintenance when it is used, and a document renewal in the spring.
CostAnalytics _sampleCost() => CostAnalytics(months: [
      _month('2025-08',
          fuel: 180,
          liters: 110,
          berth: 95,
          trips: 4,
          nm: 168,
          fuelL: 62,
          engineH: 9),
      _month('2025-09',
          fuel: 90,
          liters: 56,
          berth: 95,
          trips: 2,
          nm: 74,
          fuelL: 31,
          engineH: 5),
      _month('2025-10', berth: 95),
      _month('2025-11', berth: 95, maintenance: 340),
      _month('2025-12', berth: 95),
      _month('2026-01', berth: 95, insurance: 420),
      _month('2026-02', berth: 95),
      _month('2026-03', berth: 95, maintenance: 180, documents: 210),
      _month('2026-04',
          fuel: 130,
          liters: 78,
          berth: 95,
          trips: 3,
          nm: 96,
          fuelL: 38,
          engineH: 6),
      _month('2026-05',
          fuel: 210,
          liters: 126,
          berth: 95,
          trips: 5,
          nm: 214,
          fuelL: 74,
          engineH: 11),
      _month('2026-06',
          fuel: 160,
          liters: 95,
          berth: 95,
          trips: 4,
          nm: 152,
          fuelL: 55,
          engineH: 8),
      _month('2026-07',
          fuel: 240,
          liters: 142,
          berth: 95,
          maintenance: 120,
          trips: 6,
          nm: 268,
          fuelL: 92,
          engineH: 14),
    ]);

/// One month of the sample, with the fixed/variable split the API computes.
CostMonth _month(
  String month, {
  double fuel = 0,
  double liters = 0,
  double berth = 0,
  double insurance = 0,
  double maintenance = 0,
  double documents = 0,
  int trips = 0,
  double nm = 0,
  double fuelL = 0,
  double engineH = 0,
}) {
  return CostMonth(
    month: month,
    byCategory: {
      if (fuel > 0) 'combustible': fuel,
      if (berth > 0) 'amarre': berth,
      if (insurance > 0) 'seguro': insurance,
      if (maintenance > 0) 'maintenance': maintenance,
      if (documents > 0) 'documents': documents,
    },
    fixed: berth + insurance + documents,
    variable: fuel + maintenance,
    fuelAmount: fuel,
    fuelLiters: liters,
    trips: trips,
    distanceNm: nm,
    fuelL: fuelL,
    engineHours: engineH,
    hours: nm > 0 ? nm / 5.5 : 0,
  );
}

List<Anomaly> _sampleAnomalies() => [
      Anomaly(
        tripId: 't1',
        date: DateTime(2026, 6, 20),
        metric: 'fuel_per_nm',
        value: 0.6,
        baseline: 0.39,
        deviationPct: 52,
        distanceNm: 38,
        excessLiters: 8,
      ),
    ];

void main() {
  setUpAll(loadTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('cost analytics — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const CostAnalyticsScreen(boatId: 'boat-1'),
        brightness: brightness,
        overrides: [
          boatCostAnalyticsProvider('boat-1')
              .overrideWith((ref) async => _sampleCost()),
          boatAnomaliesProvider('boat-1')
              .overrideWith((ref) async => _sampleAnomalies()),
        ],
      );
      await expectLater(
        find.byType(CostAnalyticsScreen),
        matchesGoldenFile(goldenPath('cost_analytics', brightness)),
      );
    });
  }
}
