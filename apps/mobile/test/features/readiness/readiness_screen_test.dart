import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/screens/readiness_screen.dart';

import '../../helpers/helpers.dart';

void main() {
  Widget buildSubject(Readiness readiness) => buildTestApp(
        const ReadinessScreen(boatId: 'boat-1'),
        overrides: [
          boatReadinessProvider.overrideWith((ref, id) async => readiness),
        ],
      );

  runAsyncStateMatrix<Readiness>(
    screen: 'ReadinessScreen',
    build: (override) => buildTestApp(
      const ReadinessScreen(boatId: 'boat-1'),
      overrides: [override],
    ),
    override: (fetch) =>
        boatReadinessProvider.overrideWith((ref, id) => fetch()),
    empty: makeReadiness(categories: const [], attention: const []),
    populated: makeReadiness(),
    emptyFinder: () => find.text('Score 92 / 100'),
    populatedFinder: () => find.text('Documents'),
  );

  group('plan views', () {
    testWidgets(
        'Free partial view shows the upsell and hides gated '
        'categories', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeReadiness(full: false)));
      await pumpScreen(tester);

      expect(
        find.text('Unlock the full readiness check '
            '(safety gear + maintenance) with Pro'),
        findsOneWidget,
      );
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Safety gear'), findsNothing);
      expect(find.text('Maintenance'), findsNothing);
    });

    testWidgets('Pro full view shows all categories and no upsell',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeReadiness(
            categories: const [
              ReadinessCategory(
                key: 'documents',
                status: ReadinessStatus.ready,
                total: 3,
                expired: 0,
                critical: 0,
                warning: 0,
                ok: 3,
              ),
              ReadinessCategory(
                key: 'safety_gear',
                status: ReadinessStatus.attention,
                total: 2,
                expired: 0,
                critical: 0,
                warning: 1,
                ok: 1,
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
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Safety gear'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('3/3 OK'), findsOneWidget);
      expect(find.textContaining('Unlock the full readiness'), findsNothing);
    });
  });

  group('score bands', () {
    Readiness banded(int score, ReadinessStatus status) => makeReadiness(
          score: score,
          status: status,
          categories: const [],
          attention: const [],
        );

    testWidgets('ready shows the green ready header', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(banded(95, ReadinessStatus.ready)));
      await pumpScreen(tester);

      expect(find.text('Ready to sail'), findsOneWidget);
      expect(find.text('Score 95 / 100'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(icon.color, AppColors.green);
    });

    testWidgets('attention shows the amber warning header', (tester) async {
      setPhoneSize(tester);
      await tester
          .pumpWidget(buildSubject(banded(60, ReadinessStatus.attention)));
      await pumpScreen(tester);

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Score 60 / 100'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.warning_rounded));
      expect(icon.color, AppColors.amber);
    });

    testWidgets('not ready shows the red error header', (tester) async {
      setPhoneSize(tester);
      await tester
          .pumpWidget(buildSubject(banded(20, ReadinessStatus.notReady)));
      await pumpScreen(tester);

      expect(find.text('Not ready'), findsOneWidget);
      expect(find.text('Score 20 / 100'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_rounded));
      expect(icon.color, AppColors.red);
    });
  });

  group('attention items', () {
    testWidgets('renders every timing label branch', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeReadiness(
            categories: const [],
            attention: const [
              ReadinessItem(
                category: 'maintenance',
                ref: 'engine_service',
                label: 'Oil change',
                status: ReadinessStatus.attention,
                days: 0,
                reason: 'no_plan',
              ),
              ReadinessItem(
                category: 'maintenance',
                ref: 'engine_service',
                label: 'Impeller',
                status: ReadinessStatus.notReady,
                days: -10,
                reason: 'overdue',
              ),
              ReadinessItem(
                category: 'maintenance',
                ref: 'engine_service',
                label: 'Anodes',
                status: ReadinessStatus.attention,
                days: 0,
                reason: 'pending',
              ),
              // due_soon with the engine hours nearer than the date.
              ReadinessItem(
                category: 'maintenance',
                ref: 'engine_service',
                label: 'Coolant',
                status: ReadinessStatus.attention,
                days: 60,
                reason: 'due_soon',
                hours: 30,
              ),
              // due_soon with the date nearer than the engine hours.
              ReadinessItem(
                category: 'maintenance',
                ref: 'engine_service',
                label: 'Filters',
                status: ReadinessStatus.attention,
                days: 10,
                reason: 'due_soon',
                hours: 500,
              ),
              // due_soon with no hours falls back to the date.
              ReadinessItem(
                category: 'maintenance',
                ref: 'engine_service',
                label: 'Antifouling',
                status: ReadinessStatus.attention,
                days: 12,
                reason: 'due_soon',
              ),
              // Expired document (negative days).
              ReadinessItem(
                category: 'documents',
                ref: 'insurance_rc',
                label: 'Insurance',
                status: ReadinessStatus.notReady,
                days: -5,
              ),
              // Document expiring in N days.
              ReadinessItem(
                category: 'documents',
                ref: 'itb',
                label: 'ITB',
                status: ReadinessStatus.attention,
                days: 15,
              ),
            ],
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('set up a maintenance plan'), findsOneWidget);
      expect(find.text('overdue'), findsOneWidget);
      expect(find.text('not logged yet'), findsOneWidget);
      expect(find.text('in 30 h'), findsOneWidget);
      expect(find.text('in 10 days'), findsOneWidget);
      expect(find.text('in 12 days'), findsOneWidget);
      expect(find.text('expired'), findsOneWidget);
      expect(find.text('in 15 days'), findsOneWidget);
    });

    testWidgets('unnamed items fall back to the localized ref label',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeReadiness(
            categories: const [],
            attention: const [
              ReadinessItem(
                category: 'documents',
                ref: 'life_raft',
                status: ReadinessStatus.attention,
                days: 20,
              ),
            ],
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Life raft'), findsOneWidget);
      expect(find.text('in 20 days'), findsOneWidget);
    });

    testWidgets('attention section is hidden when there is nothing to fix',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(makeReadiness()));
      await pumpScreen(tester);

      expect(find.text('Needs attention'), findsNothing);
    });
  });
}
