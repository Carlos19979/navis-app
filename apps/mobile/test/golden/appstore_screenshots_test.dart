@Tags(['golden'])
library;

// One-off: renders real app screens at the 6.7" iPhone App Store Connect size
// (1290x2796 px = logical 430x932 @ devicePixelRatio 3.0), DARK theme, locale
// 'es', for use as App Store marketing screenshots. golden_harness.pumpGolden
// pins DPR 1.0, so this file overrides tester.view.physicalSize +
// devicePixelRatio manually (same technique as paywall_review_test.dart) and
// reuses each screen's provider-override/fake-data setup from its existing
// golden test. Regenerate with:
//   flutter test --update-goldens --tags golden test/golden/appstore_screenshots_test.dart
// Output: test/golden/goldens/appstore/*.png

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/core/theme/app_theme.dart';
import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/screens/boat_dashboard_screen.dart';
import 'package:navis_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:navis_mobile/features/cost/data/cost_repository.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/features/cost/presentation/screens/cost_analytics_screen.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/groups/data/repositories/group_repository.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

import '../helpers/billing.dart';
import '../helpers/plan.dart';
import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

/// Boat list notifier stub (copied from boat_dashboard_golden_test.dart).
class _FakeBoatsNotifier extends AsyncNotifier<List<Boat>>
    implements BoatsNotifier {
  _FakeBoatsNotifier(this._boats);
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

class _MockGroupRepository extends Mock implements GroupRepository {}

/// 6.7" iPhone App Store Connect screenshot size: 430x932 logical @ DPR 3.0.
const _logical = Size(430, 932);
const _dpr = 3.0;

/// Mirrors golden_harness.pumpGolden but keeps DPR at 3.0 (pumpGolden pins it
/// to 1.0) so the captured PNG is 1290x2796. Always dark theme, locale 'es'.
Future<void> _pumpAppStore(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = _logical * _dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await pumpGoldenFrames(tester);
  }
}

void main() {
  setUpAll(loadTestFonts);

  // (a) Boat dashboard / list.
  testWidgets('appstore — boat dashboard', (tester) async {
    final boats = [
      makeBoat(),
      makeBoat(
        id: 'boat-2',
        name: 'Sea Runner',
        type: 'motorboat',
        registration: 'ES-BCN-7-5678',
      ),
    ];
    await _pumpAppStore(
      tester,
      const BoatDashboardScreen(),
      settle: false,
      overrides: [
        ...planOverrides(),
        boatsProvider.overrideWith(() => _FakeBoatsNotifier(boats)),
        sharedBoatsProvider.overrideWith((ref) async => const <Boat>[]),
        currentWeatherProvider.overrideWith((ref) async => makeWeather()),
        boatDocumentSummaryProvider.overrideWith(
          (ref, boatId) async =>
              const DocumentSummary(total: 3, ok: 2, warning: 1),
        ),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appstore/boat_dashboard.png'),
    );
  });

  // (b) Community.
  testWidgets('appstore — community', (tester) async {
    final events = [
      makeEvent(),
      makeEvent(
        id: 'event-2',
        name: 'Trofeo Princesa Sofia',
        organizer: 'CNA',
        isFeatured: false,
      ),
    ];
    await _pumpAppStore(
      tester,
      const CommunityScreen(),
      settle: false,
      overrides: [
        ...planOverrides(),
        groupRepositoryProvider.overrideWithValue(_MockGroupRepository()),
        eventsProvider.overrideWith((ref) async => events),
        myGroupsProvider.overrideWith((ref) async => const <Group>[]),
        discoverGroupsProvider.overrideWith((ref) async => const <Group>[]),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appstore/community.png'),
    );
  });

  // (c) Weather.
  testWidgets('appstore — weather', (tester) async {
    final overview = makeOverview(
      current: makeWeather(),
      hourly: [
        for (var h = 6; h <= 20; h += 2)
          makeHourly(
            DateTime(2026, 5, 1, h),
            temperature: 16 + h / 2,
            windSpeed: 8 + h % 5,
            weatherCode: h < 12 ? 0 : 2,
            precipitationProbability: h >= 16 ? 30 : 0,
          ),
      ],
      daily: [
        for (var d = 1; d <= 7; d++)
          makeDaily(
            DateTime(2026, 5, d),
            temperatureMax: 22.0 + d,
            temperatureMin: 14.0 + d,
            windSpeed: 8.0 + d,
            weatherCode: d.isEven ? 3 : 0,
            waveHeight: 0.3 + d * 0.1,
          ),
      ],
      tideExtremes: [
        TideExtreme(
          time: DateTime(2026, 5, 1, 4, 30),
          height: 0.9,
          isHigh: true,
        ),
        TideExtreme(
          time: DateTime(2026, 5, 1, 10, 45),
          height: 0.2,
          isHigh: false,
        ),
        TideExtreme(
          time: DateTime(2026, 5, 1, 16, 50),
          height: 1.1,
          isHigh: true,
        ),
        TideExtreme(
          time: DateTime(2026, 5, 1, 23, 5),
          height: 0.1,
          isHigh: false,
        ),
      ],
    );
    await _pumpAppStore(
      tester,
      const WeatherScreen(),
      settle: false,
      overrides: [
        weatherOverviewProvider.overrideWith((ref) async => overview),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appstore/weather.png'),
    );
  });

  // (d) Cost analytics.
  testWidgets('appstore — cost analytics', (tester) async {
    const cost = CostAnalytics(
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
    final anomalies = [
      Anomaly(
        tripId: 't1',
        date: DateTime(2026, 6, 20),
        metric: 'fuel_per_nm',
        value: 0.6,
        baseline: 0.39,
        deviationPct: 52,
      ),
    ];
    await _pumpAppStore(
      tester,
      const CostAnalyticsScreen(boatId: 'boat-1'),
      overrides: [
        boatCostAnalyticsProvider('boat-1').overrideWith((ref) async => cost),
        boatAnomaliesProvider('boat-1').overrideWith((ref) async => anomalies),
      ],
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appstore/cost_analytics.png'),
    );
  });

  // (e) Paywall (reuses paywall_review_test.dart setup).
  testWidgets('appstore — paywall', (tester) async {
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = _logical * _dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final billing = MockBillingService();
    when(billing.allPackages).thenAnswer(
      (_) async => [
        makePackage(),
        makePackage(type: PackageType.annual, price: '39,99 €'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...planOverrides(),
          billingOverride(billing),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPaywall(context, ref),
                  child: const Text('open paywall'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await tester.tap(find.text('open paywall'));
    await pumpGoldenFrames(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appstore/paywall.png'),
    );
  });
}
