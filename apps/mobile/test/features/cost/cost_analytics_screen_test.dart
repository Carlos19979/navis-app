import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/cost/data/cost_repository.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/features/cost/presentation/screens/cost_analytics_screen.dart';

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

  final emptyAnalytics = makeCostAnalytics(
    totalSpend: 0,
    expenseSpend: 0,
    maintenanceSpend: 0,
    byCategory: const [],
    monthly: const [],
    totalDistanceNm: 0,
    completedTrips: 0,
    totalFuelL: 0,
    costPerNm: null,
    costPerTrip: null,
    fuelPerNm: null,
  );

  runAsyncStateMatrix<CostAnalytics>(
    screen: 'CostAnalyticsScreen',
    build: (override) => buildTestApp(
      const CostAnalyticsScreen(boatId: 'boat-1'),
      overrides: [noAnomalies, override],
    ),
    override: (fetch) =>
        boatCostAnalyticsProvider.overrideWith((ref, id) => fetch()),
    empty: emptyAnalytics,
    populated: makeCostAnalytics(),
    emptyFinder: () => find.text('—'),
    populatedFinder: () => find.text('By category'),
  );

  group('KPI row', () {
    testWidgets('shows the computed per-mile and per-trip values',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('Total spend'), findsOneWidget);
      expect(find.text('1250 €'), findsOneWidget);
      expect(find.text('Cost / NM'), findsOneWidget);
      expect(find.text('9 €'), findsOneWidget); // 8.8 rounded
      expect(find.text('Cost / trip'), findsOneWidget);
      expect(find.text('250 €'), findsOneWidget);
      expect(find.text('Fuel / NM'), findsOneWidget);
      expect(find.text('1.30 L'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('null KPIs fall back to a dash', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeCostAnalytics(
            costPerNm: null,
            costPerTrip: null,
            fuelPerNm: null,
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('1250 €'), findsOneWidget); // total is never null
    });
  });

  group('category breakdown', () {
    testWidgets('renders the section when there are categories',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('By category'), findsOneWidget);
      expect(find.text('500 €'), findsOneWidget);
      expect(find.text('Monthly spend'), findsOneWidget);
    });

    testWidgets('is hidden when there are no categories', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(makeCostAnalytics(byCategory: const [])),
      );
      await pumpScreen(tester);

      expect(find.text('By category'), findsNothing);
      expect(find.text('Monthly spend'), findsOneWidget);
    });
  });

  group('anomalies section', () {
    testWidgets('shows flagged trips when there are anomalies', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeCostAnalytics(),
          anomalies: boatAnomaliesProvider.overrideWith(
            (ref, id) async => [makeAnomaly()],
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Anomalies'), findsOneWidget);
      expect(
        find.text('Used 85% more fuel per mile than usual'),
        findsOneWidget,
      );
    });

    testWidgets('is hidden when there are none', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeCostAnalytics()));
      await pumpScreen(tester);

      expect(find.text('Anomalies'), findsNothing);
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

      expect(find.text('Anomalies'), findsNothing);
      expect(find.text('Total spend'), findsOneWidget);
    });
  });
}
