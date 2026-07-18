// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_dashboard_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';

import '../../helpers/helpers.dart';

class MockBoatRepository extends Mock implements BoatRepository {}

class FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  FakeBoatsNotifier(this._boats);
  final List<Boat> _boats;

  @override
  Future<List<Boat>> build() async => _boats;
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => boat;
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

class ErrorBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  @override
  Future<List<Boat>> build() async => throw Exception('Network error');
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => throw UnimplementedError();
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

class _NeverCompleteBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  @override
  Future<List<Boat>> build() =>
      Future<List<Boat>>.delayed(const Duration(days: 1));
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<Boat> createBoat(Boat boat) async => throw UnimplementedError();
  @override
  Future<void> updateBoat(Boat boat) async {}
  @override
  Future<void> deleteBoat(String id) async {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  final testBoats = [
    makeBoat(),
    makeBoat(
      id: 'boat-2',
      name: 'Sea Runner',
      type: 'motorboat',
      registration: 'ES-BCN-7-5678',
    ),
  ];

  Widget buildSubject({
    List<Boat> boats = const [],
    bool useError = false,
    bool isPro = false,
    RouteSpy? spy,
  }) {
    return buildRoutedTestApp(
      const BoatDashboardScreen(),
      spy: spy,
      overrides: [
        boatsProvider.overrideWith(
          () => useError ? ErrorBoatsNotifier() : FakeBoatsNotifier(boats),
        ),
        ...planOverrides(pro: isPro),
        currentWeatherProvider.overrideWith((ref) async => null),
        boatDocumentSummaryProvider.overrideWith(
          (ref, boatId) async => const DocumentSummary(),
        ),
      ],
    );
  }

  group('BoatDashboardScreen', () {
    testWidgets('shows app bar with title', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      expect(find.text('My Boats'), findsOneWidget);
    });

    testWidgets('renders boat cards with name, type, and registration',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      expect(find.text('Luna Azul'), findsOneWidget);
      expect(find.text('Sea Runner'), findsOneWidget);
      expect(find.text('ES-MAL-3-1234'), findsOneWidget);
      expect(find.text('ES-BCN-7-5678'), findsOneWidget);
      expect(find.text('Sailboat'), findsOneWidget);
      expect(find.text('Motorboat'), findsOneWidget);
    });

    testWidgets('shows length and home port info chips', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      expect(find.text('12.5 m'), findsNWidgets(2));
      expect(find.text('Palma de Mallorca'), findsNWidgets(2));
    });

    testWidgets('shows Documents and Logbook buttons per card', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      expect(find.text('Documents'), findsNWidgets(2));
      expect(find.text('Logbook'), findsNWidgets(2));
    });

    testWidgets('shows FAB with add tooltip', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      final fabWidget = tester.widget<FloatingActionButton>(fab);
      expect(fabWidget.tooltip, 'Add new boat');
    });

    testWidgets('FAB navigates to new boat page when under plan limit',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(
        buildSubject(boats: testBoats, isPro: true, spy: spy),
      );
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpScreen(tester);

      expect(spy.last, '/boats/new');
    });

    testWidgets('FAB shows paywall when free plan boat limit is reached',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(boats: testBoats, spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpScreen(tester);

      expect(spy.locations, isEmpty);
      expectPaywall();
    });

    testWidgets('FAB shows plan-limit snackbar for Pro at the 5-boat limit',
        (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      final fiveBoats = [
        for (var i = 0; i < 5; i++)
          makeBoat(id: 'boat-$i', name: 'Boat $i', registration: 'ES-V-$i'),
      ];
      await tester.pumpWidget(
        buildSubject(boats: fiveBoats, isPro: true, spy: spy),
      );
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpScreen(tester);

      expect(spy.locations, isEmpty);
      expectPaywall(shown: false);
      expectSnackbar(tester, "You've reached your plan's boat limit.");

      await drain(tester);
    });

    testWidgets('shows empty state when no boats', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: []));
      await pumpScreen(tester);

      expect(
        find.text('No boats yet. Add your first boat!'),
        findsOneWidget,
      );
      expect(find.text('Add Boat'), findsOneWidget);
    });

    testWidgets('single boat renders the boat overview (focus mode)',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: [makeBoat()]));
      await pumpScreen(tester);

      // Focus mode surfaces the Maintenance action and a manage-boat link
      // that the multi-boat card does not.
      expect(find.text('Manage boat'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('empty state Add Boat button navigates', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(boats: [], spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Add Boat'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/new');
    });

    testWidgets('shows error state with retry button', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers provider invalidation', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      await tester.tap(find.text('Retry'));
      await pumpScreen(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildRoutedTestApp(
          const BoatDashboardScreen(),
          overrides: [
            boatsProvider.overrideWith(_NeverCompleteBoatsNotifier.new),
            currentWeatherProvider.overrideWith((ref) async => null),
            boatDocumentSummaryProvider.overrideWith(
              (ref, boatId) async => const DocumentSummary(),
            ),
          ],
        ),
      );
      // Pump multiple frames to let flutter_animate's zero-duration
      // init timers fire, but not enough for the never-completing
      // provider to resolve.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BoatDashboardScreen), findsOneWidget);

      // Dispose widget tree and drain any remaining timers.
      await drain(tester);
    });

    testWidgets('boat card navigates to detail', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(boats: testBoats, spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Luna Azul'));
      await pumpScreen(tester);

      expect(spy.last, '/boats/boat-1');
    });

    testWidgets('Documents button navigates to documents page', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(boats: testBoats, spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Documents').first);
      await pumpScreen(tester);

      expect(spy.last, '/boats/boat-1/documents');
    });

    testWidgets('Logbook button navigates to trips page', (tester) async {
      setPhoneSize(tester);
      final spy = RouteSpy();
      await tester.pumpWidget(buildSubject(boats: testBoats, spy: spy));
      await pumpScreen(tester);

      await tester.tap(find.text('Logbook').first);
      await pumpScreen(tester);

      expect(spy.last, '/boats/boat-1/trips');
    });

    testWidgets('shows document summary badges when available', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildRoutedTestApp(
          const BoatDashboardScreen(),
          overrides: [
            boatsProvider.overrideWith(
              () => FakeBoatsNotifier(testBoats),
            ),
            currentWeatherProvider.overrideWith((ref) async => null),
            boatDocumentSummaryProvider.overrideWith(
              (ref, boatId) async => const DocumentSummary(
                total: 3,
                ok: 2,
                warning: 1,
              ),
            ),
          ],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('2 Valid'), findsNWidgets(2));
      expect(find.text('1 Warning'), findsNWidgets(2));
    });

    testWidgets('pull to refresh works on boat list', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      await tester.fling(
        find.text('Luna Azul'),
        const Offset(0, 300),
        1000,
      );
      await pumpScreen(tester);

      expect(find.text('Luna Azul'), findsOneWidget);
    });
  });
}
