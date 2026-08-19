import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/features/cost/presentation/screens/cost_analytics_screen.dart';
import 'package:navis_mobile/shared/widgets/navis_period_chip.dart';

import '../../helpers/helpers.dart';

void main() {
  final noAnomalies = boatAnomaliesProvider.overrideWith(
    (ref, id) async => const <Anomaly>[],
  );

  Widget buildSubject(
    CostAnalytics analytics, {
    Override? anomalies,
  }) =>
      buildTestApp(
        const CostAnalyticsScreen(boatId: 'boat-1'),
        overrides: [
          anomalies ?? noAnomalies,
          boatCostAnalyticsProvider.overrideWith((ref, id) async => analytics),
        ],
      );

  /// The period chips share their text with the trend chart's axis labels, so
  /// the chip has to be named, not just the string.
  Future<void> pickPeriod(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(NavisPeriodChip, label));
    await pumpScreen(tester);
  }

  runAsyncStateMatrix<CostAnalytics>(
    screen: 'CostAnalyticsScreen',
    build: (override) => buildTestApp(
      const CostAnalyticsScreen(boatId: 'boat-1'),
      overrides: [noAnomalies, override],
    ),
    override: (fetch) =>
        boatCostAnalyticsProvider.overrideWith((ref, id) => fetch()),
    empty: CostAnalytics.empty,
    populated: makeCostAnalytics(),
    emptyFinder: () => find.text('No costs yet'),
    populatedFinder: () => find.text('BY CATEGORY'),
  );

  group('headline', () {
    testWidgets('names the period and breaks the total down by source',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      // All time by default: 400 + 850 across the two sample months.
      expect(find.text('Total cost · All time'), findsOneWidget);
      expect(find.text('1,250 €'), findsWidgets);

      // The three sources, so the number can say what it is made of — the
      // question the old screen left unanswered.
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('1,050 €'), findsOneWidget); // fuel + berth + insurance
      // Also a category row further down, hence findsWidgets.
      expect(find.text('Maintenance'), findsWidgets);
      expect(find.text('150 €'), findsWidgets);
      expect(find.text('Document renewals'), findsWidgets);
      expect(find.text('50 €'), findsWidgets);
    });

    testWidgets('shows the miles and trips behind the ratios', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('142.3 NM · 5 trips'), findsOneWidget);
    });
  });

  group('period control', () {
    testWidgets('offers only years and months that have data', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('All time'), findsOneWidget);
      expect(find.text('2026'), findsWidgets);
      expect(find.text('2025'), findsNothing);
      // The month row only appears once a year is selected.
      expect(find.text('Whole year'), findsNothing);
    });

    testWidgets('picking a month recomputes every figure without refetching',
        (tester) async {
      setPhoneSize(tester);
      var fetches = 0;
      await tester.pumpWidget(
        buildTestApp(
          const CostAnalyticsScreen(boatId: 'boat-1'),
          overrides: [
            noAnomalies,
            boatCostAnalyticsProvider.overrideWith((ref, id) async {
              fetches++;
              return makeCostAnalytics();
            }),
          ],
        ),
      );
      await pumpScreen(tester);
      expect(fetches, 1);

      await pickPeriod(tester, '2026');
      await pickPeriod(tester, 'Mar');

      // March alone: 200 fuel + 150 berth + 50 maintenance.
      expect(find.text('Total cost · March 2026'), findsOneWidget);
      expect(find.text('400 €'), findsOneWidget);
      expect(find.text('1,250 €'), findsNothing);
      // The whole series arrived in the first response — chips are arithmetic.
      expect(fetches, 1);
    });

    testWidgets('a month is compared against the month before it',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      await pickPeriod(tester, '2026');
      await pickPeriod(tester, 'Apr');

      // 850 against March's 400: +113%.
      expect(find.textContaining('vs. March 2026'), findsOneWidget);
    });
  });

  group('run rate', () {
    testWidgets('states the €/month and €/year and what they are based on',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      // 1250 € over the two months on record.
      expect(find.text('625 €/month'), findsOneWidget);
      expect(find.text('7,500 €/year'), findsOneWidget);
      expect(find.text('Over 2 months with records'), findsOneWidget);
    });

    testWidgets('is hidden for a single month, where the total is the rate',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      await pickPeriod(tester, '2026');
      await pickPeriod(tester, 'Mar');

      expect(find.text('Cost run rate'), findsNothing);
    });
  });

  group('ratios', () {
    testWidgets('are computed for the period', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('Cost / NM'), findsOneWidget);
      expect(find.text('9 €'), findsOneWidget); // 1250 / 142.3
      expect(find.text('Cost / trip'), findsOneWidget);
      expect(find.text('250 €'), findsWidgets);
      expect(find.text('Cost / engine h'), findsOneWidget);
      expect(find.text('63 €'), findsOneWidget); // 1250 / 20
      expect(find.text('1.26 L/NM'), findsOneWidget);
      expect(find.text('1.67 €/L'), findsOneWidget); // 500 / 300
      expect(find.text('300 L'), findsOneWidget);
    });

    testWidgets('fall back to a dash when the denominator is missing',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(CostAnalytics(months: [
          makeCostMonth(
            '2026-03',
            byCategory: const {'amarre': 400},
            fixed: 400,
          ),
        ])),
      );
      await pumpScreen(tester);

      // A berth paid on a boat that never left: no miles, trips, engine hours,
      // litres or price per litre.
      expect(find.text('—'), findsNWidgets(6));
      expect(find.text('400 €'), findsWidgets);
    });
  });

  group('fixed vs variable', () {
    testWidgets('splits the period and explains the split', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('Fixed and variable'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);
      expect(find.text('600 €'), findsOneWidget);
      expect(find.text('Variable'), findsOneWidget);
      expect(find.text('650 €'), findsOneWidget);
      expect(
        find.textContaining('owed even if the boat never leaves'),
        findsOneWidget,
      );
    });
  });

  group('category breakdown', () {
    testWidgets('lists categories biggest first', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('BY CATEGORY'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('500 €'), findsWidgets);
      expect(find.text('Mooring'), findsOneWidget);
      expect(find.text('Insurance'), findsOneWidget);
      expect(find.text('Maintenance'), findsWidgets);
    });

    testWidgets('is hidden for a period with no spend', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(CostAnalytics(months: [
          makeCostMonth('2026-03', trips: 1, distanceNm: 20),
        ])),
      );
      await pumpScreen(tester);

      expect(find.text('BY CATEGORY'), findsNothing);
      expect(find.text('Fixed and variable'), findsNothing);
    });
  });

  group('trend', () {
    testWidgets('shows a bar per year on all time', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(CostAnalytics(months: [
          makeCostMonth('2025-01',
              byCategory: const {'combustible': 100}, variable: 100),
          makeCostMonth('2026-01',
              byCategory: const {'combustible': 300}, variable: 300),
        ])),
      );
      await pumpScreen(tester);

      expect(find.text('TREND'), findsOneWidget);
      // Bars labelled by year, and tapping one drills into it.
      await tester.tap(find.text('2025').last);
      await pumpScreen(tester);
      expect(find.text('Total cost · 2025'), findsOneWidget);
    });
  });

  group('anomalies', () {
    testWidgets('prices the wasted fuel with the period €/L', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeCostAnalytics(),
          anomalies: boatAnomaliesProvider.overrideWith(
            (ref, id) async => [makeAnomaly(date: DateTime(2026, 4, 12))],
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('ANOMALIES'), findsOneWidget);
      expect(
        find.text('Used 85% more fuel per mile than usual'),
        findsOneWidget,
      );
      // 20 excess litres at the sample's 1.67 €/L.
      expect(find.text('33 € of extra fuel'), findsOneWidget);
    });

    testWidgets('only shows the ones inside the period', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeCostAnalytics(),
          anomalies: boatAnomaliesProvider.overrideWith(
            (ref, id) async => [makeAnomaly(date: DateTime(2026, 4, 12))],
          ),
        ),
      );
      await pumpScreen(tester);

      await pickPeriod(tester, '2026');
      await pickPeriod(tester, 'Mar');

      expect(find.text('ANOMALIES'), findsNothing);
    });

    testWidgets('is hidden when there are none', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('ANOMALIES'), findsNothing);
    });

    testWidgets('is hidden when the anomalies fetch fails (e.g. Free plan)',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeCostAnalytics(),
          anomalies: boatAnomaliesProvider.overrideWith(
            (ref, id) async => throw Exception('402 payment required'),
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('ANOMALIES'), findsNothing);
      expect(find.text('1,250 €'), findsWidgets);
    });
  });

  group('empty boat', () {
    testWidgets('invites the first entry instead of showing zeroes',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(CostAnalytics.empty));
      await pumpScreen(tester);

      expect(find.text('No costs yet'), findsOneWidget);
      expect(find.text('Add an expense'), findsOneWidget);
      // None of the cards: there is nothing to slice.
      expect(find.text('Cost / NM'), findsNothing);
      expect(find.text('All time'), findsNothing);
    });
  });

  group('load error', () {
    testWidgets('shows a message an owner can act on, not the exception',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildTestApp(
          const CostAnalyticsScreen(boatId: 'boat-1'),
          overrides: [
            noAnomalies,
            boatCostAnalyticsProvider.overrideWith(
              (ref, id) async => throw Exception('DioException [500]'),
            ),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Could not load costs'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });
  });
}
