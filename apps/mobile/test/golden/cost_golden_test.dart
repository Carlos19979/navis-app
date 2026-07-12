@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/cost/data/cost_repository.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/features/cost/presentation/screens/cost_analytics_screen.dart';

import 'golden_harness.dart';

CostAnalytics _sampleCost() => const CostAnalytics(
      totalSpend: 1840,
      expenseSpend: 1200,
      maintenanceSpend: 640,
      byCategory: [
        CostBreakdownItem(key: 'combustible', amount: 720),
        CostBreakdownItem(key: 'maintenance', amount: 640),
        CostBreakdownItem(key: 'amarre', amount: 320),
        CostBreakdownItem(key: 'seguro', amount: 160),
      ],
      monthly: [
        CostMonthly(month: '2025-08', amount: 210),
        CostMonthly(month: '2025-09', amount: 90),
        CostMonthly(month: '2025-10', amount: 0),
        CostMonthly(month: '2025-11', amount: 340),
        CostMonthly(month: '2025-12', amount: 120),
        CostMonthly(month: '2026-01', amount: 60),
        CostMonthly(month: '2026-02', amount: 0),
        CostMonthly(month: '2026-03', amount: 180),
        CostMonthly(month: '2026-04', amount: 240),
        CostMonthly(month: '2026-05', amount: 150),
        CostMonthly(month: '2026-06', amount: 90),
        CostMonthly(month: '2026-07', amount: 90),
      ],
      totalDistanceNm: 460,
      completedTrips: 12,
      totalFuelL: 180,
      costPerNm: 4,
      costPerTrip: 153,
      fuelPerNm: 0.39,
    );

List<Anomaly> _sampleAnomalies() => [
      Anomaly(
        tripId: 't1',
        date: DateTime(2026, 6, 20),
        metric: 'fuel_per_nm',
        value: 0.6,
        baseline: 0.39,
        deviationPct: 52,
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
