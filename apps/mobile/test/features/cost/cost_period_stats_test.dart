import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/cost/domain/cost_period_stats.dart';
import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';
import 'package:navis_mobile/shared/models/analytics_period.dart';

import '../../helpers/helpers.dart';

/// A month whose spend is one category, on the right side of the split.
CostMonth spend(String month, String category, double amount,
        {bool fixed = false}) =>
    makeCostMonth(
      month,
      byCategory: {category: amount},
      fixed: fixed ? amount : 0,
      variable: fixed ? 0 : amount,
    );

void main() {
  group('period selection', () {
    // A year and a bit of history: 2025 complete, 2026 up to April — the shape
    // the API sends, zero-filled to the current month.
    final analytics = CostAnalytics(months: [
      for (var m = 1; m <= 12; m++)
        spend('2025-${m.toString().padLeft(2, '0')}', 'amarre', 100,
            fixed: true),
      spend('2026-01', 'combustible', 200),
      makeCostMonth('2026-02'),
      spend('2026-03', 'combustible', 400),
      spend('2026-04', 'seguro', 300, fixed: true),
    ]);

    test('all time sums every month', () {
      final stats = costStatsFor(analytics, const AnalyticsPeriod.allTime());
      expect(stats.total, 1200 + 200 + 400 + 300);
      expect(stats.recordedMonths, 16);
      // Nothing before all time, so no comparison to make.
      expect(stats.previousTotal, isNull);
      expect(stats.deltaPct, isNull);
    });

    test('a year sums only its own months', () {
      final stats = costStatsFor(analytics, const AnalyticsPeriod.year(2026));
      expect(stats.total, 900);
      // Only the elapsed months of the year in progress.
      expect(stats.recordedMonths, 4);
    });

    test('a month sums only itself', () {
      final stats =
          costStatsFor(analytics, const AnalyticsPeriod.month(2026, 3));
      expect(stats.total, 400);
      expect(stats.recordedMonths, 1);
    });

    test('a period with no months at all is empty', () {
      final stats = costStatsFor(analytics, const AnalyticsPeriod.year(2019));
      expect(stats, same(CostPeriodStats.empty));
      expect(stats.total, 0);
    });

    test('an empty month keeps its place and reads as zero', () {
      final stats =
          costStatsFor(analytics, const AnalyticsPeriod.month(2026, 2));
      expect(stats.total, 0);
      expect(stats.hasSpend, isFalse);
      expect(stats.recordedMonths, 1);
    });
  });

  group('comparison with the previous period', () {
    final analytics = CostAnalytics(months: [
      spend('2025-01', 'combustible', 100),
      spend('2026-01', 'combustible', 150),
      spend('2026-02', 'combustible', 75),
    ]);

    test('a year compares against the year before', () {
      final stats = costStatsFor(analytics, const AnalyticsPeriod.year(2026));
      expect(stats.previousTotal, 100);
      expect(stats.deltaPct, 125);
    });

    test('a month compares against the month before', () {
      final stats =
          costStatsFor(analytics, const AnalyticsPeriod.month(2026, 2));
      expect(stats.previousTotal, 150);
      expect(stats.deltaPct, -50);
    });

    test('january compares against december of the year before', () {
      expect(
        const AnalyticsPeriod.month(2026, 1).previous,
        const AnalyticsPeriod.month(2025, 12),
      );
    });

    test('no delta when the previous period had nothing', () {
      final stats = costStatsFor(analytics, const AnalyticsPeriod.year(2025));
      // 2024 is not in the series at all.
      expect(stats.previousTotal, isNull);
      expect(stats.deltaPct, isNull);
    });
  });

  group('the sources the total is made of', () {
    final stats = costStatsFor(
      CostAnalytics(months: [
        makeCostMonth(
          '2026-05',
          byCategory: const {
            'combustible': 300,
            'amarre': 200,
            'maintenance': 150,
            'documents': 450,
          },
          fixed: 650,
          variable: 450,
        ),
      ]),
      const AnalyticsPeriod.month(2026, 5),
    );

    test('splits expenses, maintenance and document renewals', () {
      expect(stats.expenses, 500); // fuel + berth
      expect(stats.maintenance, 150);
      expect(stats.documents, 450);
      // The three add up to the headline — which is the whole point of showing
      // them under it.
      expect(stats.expenses + stats.maintenance + stats.documents, stats.total);
    });

    test('carries the fixed/variable split the API computed', () {
      expect(stats.fixed, 650);
      expect(stats.variable, 450);
      expect(stats.fixedShare, closeTo(0.59, 0.01));
    });
  });

  group('ratios', () {
    CostPeriodStats statsWith({
      double amount = 1000,
      int trips = 0,
      double distanceNm = 0,
      double fuelL = 0,
      double engineHours = 0,
      double fuelAmount = 0,
      double fuelLiters = 0,
    }) =>
        costStatsFor(
          CostAnalytics(months: [
            makeCostMonth(
              '2026-06',
              byCategory: {'combustible': amount},
              variable: amount,
              trips: trips,
              distanceNm: distanceNm,
              fuelL: fuelL,
              engineHours: engineHours,
              fuelAmount: fuelAmount,
              fuelLiters: fuelLiters,
            ),
          ]),
          const AnalyticsPeriod.month(2026, 6),
        );

    test('are computed when the denominator is there', () {
      final stats = statsWith(
        trips: 4,
        distanceNm: 200,
        fuelL: 90,
        engineHours: 25,
        fuelAmount: 600,
        fuelLiters: 400,
      );
      expect(stats.costPerNm, 5);
      expect(stats.costPerTrip, 250);
      expect(stats.costPerEngineHour, 40);
      expect(stats.litresPerNm, 0.45);
      expect(stats.pricePerLiter, 1.5);
    });

    test('are null rather than zero when the denominator is missing', () {
      final stats = statsWith();
      expect(stats.costPerNm, isNull);
      expect(stats.costPerTrip, isNull);
      expect(stats.costPerEngineHour, isNull);
      expect(stats.litresPerNm, isNull);
      expect(stats.pricePerLiter, isNull);
    });

    test('litres per mile needs fuel, not just distance', () {
      // A sailing month: miles covered, no engine.
      expect(statsWith(distanceNm: 120).litresPerNm, isNull);
    });
  });

  group('run rate', () {
    test('divides by the months on record, not the months with spend', () {
      // One 1200 € haul-out in a twelve-month year is 100 €/month, not 1200.
      final analytics = CostAnalytics(months: [
        spend('2026-01', 'reparación', 1200),
        for (var m = 2; m <= 12; m++)
          makeCostMonth('2026-${m.toString().padLeft(2, '0')}'),
      ]);
      final stats = costStatsFor(analytics, const AnalyticsPeriod.year(2026));
      expect(stats.recordedMonths, 12);
      expect(stats.monthlyRunRate, 100);
      expect(stats.projectedYear, 1200);
    });

    test('a year in progress annualises from the months lived so far', () {
      final analytics = CostAnalytics(months: [
        spend('2026-01', 'amarre', 300, fixed: true),
        spend('2026-02', 'amarre', 300, fixed: true),
        spend('2026-03', 'amarre', 300, fixed: true),
      ]);
      final stats = costStatsFor(analytics, const AnalyticsPeriod.year(2026));
      expect(stats.monthlyRunRate, 300);
      expect(stats.projectedYear, 3600);
    });

    test('a single month has no rate of its own', () {
      final analytics = CostAnalytics(months: [
        spend('2026-01', 'amarre', 300, fixed: true),
      ]);
      final stats =
          costStatsFor(analytics, const AnalyticsPeriod.month(2026, 1));
      expect(stats.monthlyRunRate, isNull);
      expect(stats.projectedYear, isNull);
    });
  });

  group('by category', () {
    test('is biggest first and carries the previous period', () {
      final analytics = CostAnalytics(months: [
        makeCostMonth(
          '2026-01',
          byCategory: const {'combustible': 100, 'amarre': 300},
          variable: 100,
          fixed: 300,
        ),
        makeCostMonth(
          '2026-02',
          byCategory: const {'combustible': 250, 'amarre': 300},
          variable: 250,
          fixed: 300,
        ),
      ]);
      final stats =
          costStatsFor(analytics, const AnalyticsPeriod.month(2026, 2));

      expect(stats.byCategory.map((c) => c.key), ['amarre', 'combustible']);
      expect(stats.byCategory.first.deltaPct, 0);
      expect(stats.byCategory.last.deltaPct, 150);
    });

    test('a category absent from the previous period has no percentage', () {
      final analytics = CostAnalytics(months: [
        spend('2026-01', 'amarre', 300, fixed: true),
        makeCostMonth(
          '2026-02',
          byCategory: const {'amarre': 300, 'reparación': 80},
          fixed: 300,
          variable: 80,
        ),
      ]);
      final stats =
          costStatsFor(analytics, const AnalyticsPeriod.month(2026, 2));
      final repair = stats.byCategory.firstWhere((c) => c.key == 'reparación');
      // Growth from nothing is not a percentage.
      expect(repair.previousAmount, 0);
      expect(repair.deltaPct, isNull);
    });
  });

  group('the periods the picker offers', () {
    final analytics = CostAnalytics(months: [
      spend('2024-06', 'amarre', 100, fixed: true),
      makeCostMonth('2025-01'), // zero-filled, no data
      makeCostMonth('2026-01', trips: 1, distanceNm: 12), // sailed, no spend
      spend('2026-05', 'combustible', 50),
    ]);

    test('only years with something recorded, most recent first', () {
      expect(yearsWithCosts(analytics), [2026, 2024]);
    });

    test('a month that only has trips still counts as data', () {
      expect(monthsWithCosts(analytics, 2026), {1, 5});
    });

    test('a zero-filled year offers nothing', () {
      expect(monthsWithCosts(analytics, 2025), isEmpty);
    });
  });
}
