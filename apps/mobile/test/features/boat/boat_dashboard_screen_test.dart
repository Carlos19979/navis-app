// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_dashboard_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';

import '../../helpers/test_helpers.dart';

class MockBoatRepository extends Mock implements BoatRepository {}

class FakeRoute extends Fake implements Route<dynamic> {}

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

/// Creates a GoRouter that renders the given child at '/' and
/// handles all other routes with a placeholder page, preventing
/// navigation errors in widget tests.
GoRouter _testRouter(Widget child) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => child,
      ),
      // Catch-all for any navigation triggered by taps
      GoRoute(
        path: '/boats/new',
        builder: (_, __) => const Scaffold(body: Text('New Boat Page')),
      ),
      GoRoute(
        path: '/boats/:id',
        builder: (_, __) => const Scaffold(body: Text('Boat Detail Page')),
        routes: [
          GoRoute(
            path: 'documents',
            builder: (_, __) => const Scaffold(body: Text('Documents Page')),
          ),
          GoRoute(
            path: 'trips',
            builder: (_, __) => const Scaffold(body: Text('Trips Page')),
          ),
        ],
      ),
    ],
  );
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
  }) {
    final router = _testRouter(const BoatDashboardScreen());
    return ProviderScope(
      overrides: [
        boatsProvider.overrideWith(
          () => useError ? ErrorBoatsNotifier() : FakeBoatsNotifier(boats),
        ),
        proEntitlementProvider.overrideWith((ref) => isPro),
        currentWeatherProvider.overrideWith((ref) async => null),
        boatDocumentSummaryProvider.overrideWith(
          (ref, boatId) async => const DocumentSummary(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
      ),
    );
  }

  /// Pump enough frames for async providers and animation init
  /// without pumpAndSettle (which never completes due to
  /// flutter_animate's repeating animations).
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('BoatDashboardScreen', () {
    testWidgets('shows app bar with title', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      expect(find.text('My Boats'), findsOneWidget);
    });

    testWidgets('renders boat cards with name, type, and registration',
        (tester) async {
      await setPhoneSize(tester);
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
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      expect(find.text('12.5 m'), findsNWidgets(2));
      expect(find.text('Palma de Mallorca'), findsNWidgets(2));
    });

    testWidgets('shows Documents and Logbook buttons per card', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      expect(find.text('Documents'), findsNWidgets(2));
      expect(find.text('Logbook'), findsNWidgets(2));
    });

    testWidgets('shows FAB with add tooltip', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      final fabWidget = tester.widget<FloatingActionButton>(fab);
      expect(fabWidget.tooltip, 'Add new boat');
    });

    testWidgets('FAB navigates to new boat page when under plan limit',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats, isPro: true));
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpScreen(tester);

      expect(find.text('New Boat Page'), findsOneWidget);
    });

    testWidgets('FAB shows paywall when free plan boat limit is reached',
        (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await pumpScreen(tester);

      expect(find.text('New Boat Page'), findsNothing);
      expect(find.text('Navis Pro'), findsOneWidget);
    });

    testWidgets('shows empty state when no boats', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: []));
      await pumpScreen(tester);

      expect(
        find.text('No boats yet. Add your first boat!'),
        findsOneWidget,
      );
      expect(find.text('Add Boat'), findsOneWidget);
    });

    testWidgets('empty state Add Boat button navigates', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: []));
      await pumpScreen(tester);

      await tester.tap(find.text('Add Boat'));
      await pumpScreen(tester);

      expect(find.text('New Boat Page'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button triggers provider invalidation', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(useError: true));
      await pumpScreen(tester);

      await tester.tap(find.text('Retry'));
      await pumpScreen(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await setPhoneSize(tester);
      final router = _testRouter(const BoatDashboardScreen());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            boatsProvider.overrideWith(_NeverCompleteBoatsNotifier.new),
            currentWeatherProvider.overrideWith((ref) async => null),
            boatDocumentSummaryProvider.overrideWith(
              (ref, boatId) async => const DocumentSummary(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('es'),
            ],
          ),
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
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('boat card navigates to detail', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      await tester.tap(find.text('Luna Azul'));
      await pumpScreen(tester);

      expect(find.text('Boat Detail Page'), findsOneWidget);
    });

    testWidgets('Documents button navigates to documents page', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      await tester.tap(find.text('Documents').first);
      await pumpScreen(tester);

      expect(find.text('Documents Page'), findsOneWidget);
    });

    testWidgets('Logbook button navigates to trips page', (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(boats: testBoats));
      await pumpScreen(tester);

      await tester.tap(find.text('Logbook').first);
      await pumpScreen(tester);

      expect(find.text('Trips Page'), findsOneWidget);
    });

    testWidgets('shows document summary badges when available', (tester) async {
      await setPhoneSize(tester);
      final router = _testRouter(const BoatDashboardScreen());
      await tester.pumpWidget(
        ProviderScope(
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
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('es'),
            ],
          ),
        ),
      );
      await pumpScreen(tester);

      expect(find.text('2 Valid'), findsNWidgets(2));
      expect(find.text('1 Warning'), findsNWidgets(2));
    });

    testWidgets('pull to refresh works on boat list', (tester) async {
      await setPhoneSize(tester);
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
