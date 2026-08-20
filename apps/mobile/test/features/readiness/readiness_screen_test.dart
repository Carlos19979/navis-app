import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/screens/readiness_screen.dart';

import 'package:navis_mobile/shared/widgets/navis_ring.dart';

import '../../helpers/helpers.dart';
import '../../helpers/text_layout.dart';

void main() {
  Widget buildSubject(Readiness readiness) => buildTestApp(
        const ReadinessScreen(boatId: 'boat-1'),
        overrides: [
          boatReadinessProvider.overrideWith((ref, id) async => readiness),
        ],
      );

  Widget buildRoutedSubject(Readiness readiness, RouteSpy spy) =>
      buildRoutedTestApp(
        const ReadinessScreen(boatId: 'boat-1'),
        spy: spy,
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
    // The score lives inside the ring now.
    emptyFinder: () => find.byType(NavisRing),
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
        // The upsell names Plus now: the full check is a Plus feature, and the
        // copy promised Pro.
        find.text('The full check — safety gear and maintenance — '
            'is part of Navis Plus'),
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
      // The figure is inside the ring, and the arc is what says how far
      // along: the header used to lead with a 44 px alarm icon and the words
      // «Score 95 / 100» under it.
      final finder = find.byType(NavisRing);
      final ring = tester.widget<NavisRing>(finder);
      expect(ring.value, 95);
      // Resolved from the pumped context, not hard-coded: each accent has a
      // light and a dark value, and asserting one of them would pin the test
      // to whichever theme the helper happens to build.
      expect(ring.color, tester.element(finder).positiveFill);
    });

    testWidgets('attention shows the amber warning header', (tester) async {
      setPhoneSize(tester);
      await tester
          .pumpWidget(buildSubject(banded(60, ReadinessStatus.attention)));
      await pumpScreen(tester);

      expect(find.text('Needs attention'), findsOneWidget);
      // The figure is inside the ring, and the arc is what says how far
      // along: the header used to lead with a 44 px alarm icon and the words
      // «Score 60 / 100» under it.
      final finder = find.byType(NavisRing);
      final ring = tester.widget<NavisRing>(finder);
      expect(ring.value, 60);
      // Resolved from the pumped context, not hard-coded: each accent has a
      // light and a dark value, and asserting one of them would pin the test
      // to whichever theme the helper happens to build.
      expect(ring.color, tester.element(finder).cautionFill);
    });

    testWidgets('not ready shows the red error header', (tester) async {
      setPhoneSize(tester);
      await tester
          .pumpWidget(buildSubject(banded(20, ReadinessStatus.notReady)));
      await pumpScreen(tester);

      expect(find.text('Not ready'), findsOneWidget);
      // The figure is inside the ring, and the arc is what says how far
      // along: the header used to lead with a 44 px alarm icon and the words
      // «Score 20 / 100» under it.
      final finder = find.byType(NavisRing);
      final ring = tester.widget<NavisRing>(finder);
      expect(ring.value, 20);
      // Resolved from the pumped context, not hard-coded: each accent has a
      // light and a dark value, and asserting one of them would pin the test
      // to whichever theme the helper happens to build.
      expect(ring.color, tester.element(finder).criticalFill);
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

      // The section heading is tracked uppercase; the status word in the
      // header is not.
      expect(find.text('NEEDS ATTENTION'), findsOneWidget);
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

      expect(find.text('NEEDS ATTENTION'), findsNothing);
    });
  });

  group('layout on a narrow phone', () {
    // The reported bug: "Mantenimiento" rendered as "Mantenimi/ento" because
    // the long status text next to it took the whole row.
    testWidgets('a long status does not squeeze the item label',
        (tester) async {
      setNarrowPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeReadiness(
            categories: const [],
            attention: const [
              ReadinessItem(
                category: 'maintenance',
                ref: 'engine_service',
                status: ReadinessStatus.attention,
                days: 0,
                reason: 'no_plan',
              ),
            ],
          ),
        ),
      );
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expectFullyLaidOut(tester, find.text('Maintenance'));
      expectFullyLaidOut(tester, find.text('set up a maintenance plan'));
    });

    testWidgets('category rows keep their label intact', (tester) async {
      setNarrowPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          makeReadiness(
            categories: const [
              ReadinessCategory(
                key: 'safety_gear',
                status: ReadinessStatus.attention,
                total: 2,
                expired: 0,
                critical: 0,
                warning: 1,
                ok: 1,
              ),
            ],
            attention: const [],
          ),
        ),
      );
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expectFullyLaidOut(tester, find.text('1/2 OK'));
    });
  });

  group('deep links', () {
    testWidgets('a maintenance warning opens the maintenance screen',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedSubject(
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
            ],
          ),
          spy,
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Oil change'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/boat-1/maintenance');
    });

    testWidgets('a document warning opens the documents screen',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedSubject(
          makeReadiness(
            categories: const [],
            attention: const [
              ReadinessItem(
                category: 'documents',
                ref: 'insurance_rc',
                label: 'Insurance',
                status: ReadinessStatus.notReady,
                days: -5,
              ),
            ],
          ),
          spy,
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Insurance'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/boat-1/documents');
    });

    testWidgets('a safety-gear warning opens the documents screen',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedSubject(
          makeReadiness(
            categories: const [],
            attention: const [
              ReadinessItem(
                category: 'safety_gear',
                ref: 'life_raft',
                status: ReadinessStatus.attention,
                days: 20,
              ),
            ],
          ),
          spy,
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Life raft'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/boat-1/documents');
    });

    testWidgets('category rows open their own screen', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildRoutedSubject(
          makeReadiness(
            categories: const [
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
            attention: const [],
          ),
          spy,
        ),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Maintenance'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/boat-1/maintenance');
    });
  });
}
