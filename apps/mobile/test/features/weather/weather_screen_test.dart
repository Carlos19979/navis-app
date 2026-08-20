import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/current_conditions.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/daily_forecast_list.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/hourly_forecast_strip.dart';

import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';

import '../../helpers/helpers.dart';

void main() {
  // Disable flutter_animate durations so animations complete instantly
  // in tests, preventing pumpAndSettle timeouts.
  setUpAll(() {
    Animate.restartOnHotReload = false;
  });

  setUp(() {
    Animate.defaultDuration = Duration.zero;
  });

  tearDown(() {
    Animate.defaultDuration = const Duration(milliseconds: 300);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Override> overrides,
  }) async {
    await tester.pumpWidget(
      buildTestApp(const WeatherScreen(), overrides: overrides),
    );
    // Eight frames, not two: the sections enter staggered now, and a delayed
    // entrance is a real timer — a test that stopped pumping at 50 ms ended
    // with one pending and failed on teardown rather than on an assertion.
    await pumpFrames(tester, frames: 8);
    // The empty state's float is bounded but longer than the test; dispose the
    // tree so it does not outlive the case that built it.
    addTearDown(() => drain(tester));
  }

  group('WeatherScreen', () {
    group('loaded state', () {
      testWidgets('renders without errors when overview is loaded',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(WeatherScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows app bar title', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.text('Weather'), findsOneWidget);
      });

      testWidgets('shows hero temperature rounded to integer', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        // makeWeather() temperature is 24.0
        expect(find.text('24°'), findsOneWidget);
      });

      testWidgets('shows localized weather description from code',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        // current weatherCode 0 -> "Clear"
        expect(find.text('Clear'), findsOneWidget);
      });

      testWidgets('shows today high and low temperatures', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        // daily[0] is 26 / 18
        expect(find.text('26°'), findsWidgets);
        expect(find.text('18°'), findsWidgets);
      });

      testWidgets('shows the daily forecast list', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(DailyForecastList), findsOneWidget);
      });

      testWidgets('days start collapsed, with no hourly strip on screen',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(HourlyForecastStrip), findsNothing);
      });

      testWidgets("tapping today expands the overview's own hours",
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        await tester.tap(find.text('Today'));
        await tester.pumpAndSettle();

        // Bundled with the overview: expanding needs no extra fetch.
        expect(find.byType(HourlyForecastStrip), findsOneWidget);
      });

      testWidgets('tapping an expanded day collapses it again', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        await tester.tap(find.text('Today'));
        await tester.pumpAndSettle();
        expect(find.byType(HourlyForecastStrip), findsOneWidget);

        await tester.tap(find.text('Today'));
        await tester.pumpAndSettle();
        expect(find.byType(HourlyForecastStrip), findsNothing);
      });

      testWidgets('shows wind, waves and humidity as metric tiles',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(CurrentConditions), findsOneWidget);
        expect(find.text('WIND'), findsOneWidget);
        expect(find.text('WAVES'), findsOneWidget);
        expect(find.text('HUMIDITY'), findsOneWidget);
        // makeWeather(): wind 12 kt from 225 deg, waveHeight 0.8, humidity 65.
        expect(find.text('12'), findsOneWidget);
        expect(find.text('kt'), findsOneWidget);
        expect(find.text('0.8'), findsOneWidget);
        expect(find.text('65'), findsOneWidget);
        // Direction as text instead of the old compass dial.
        expect(find.text('SW  225°'), findsOneWidget);
      });

      testWidgets('grades wind and waves for screen readers', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(
              current: makeWeather(windSpeed: 5, waveHeight: 0.2),
            ),
          ),
        ]);

        // The gauge color grades the metric visually; the word only exists in
        // the semantics label, so that is where it has to be asserted. Both
        // metrics sit under their first threshold, hence two 'Calm'.
        final graded = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .map((s) => s.properties.label)
            .whereType<String>()
            .where((label) => label.contains('Calm'));

        expect(graded.length, 2);
      });

      testWidgets('shows the forecast heading', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        // Tracked uppercase now, like every other section heading.
        expect(find.text('7-DAY FORECAST'), findsOneWidget);
      });

      testWidgets("expanding a future day loads that day's hourly forecast",
          (tester) async {
        final today = DateTime(2026, 5);
        final tomorrow = DateTime(2026, 5, 2);
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(
              daily: [makeDaily(today), makeDaily(tomorrow)],
            ),
          ),
          hourlyForDayProvider(tomorrow).overrideWith(
            (ref) async =>
                [makeHourly(DateTime(2026, 5, 2, 9), temperature: 15)],
          ),
        ]);

        // Tap tomorrow's row; its hours are fetched and shown in place.
        final row = find.text('Sat');
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(find.byType(HourlyForecastStrip), findsOneWidget);
        expect(find.text('15°'), findsWidgets);
      });

      testWidgets('a day whose hours fail to load offers a retry, inline',
          (tester) async {
        final today = DateTime(2026, 5);
        final tomorrow = DateTime(2026, 5, 2);
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(
              daily: [makeDaily(today), makeDaily(tomorrow)],
            ),
          ),
          hourlyForDayProvider(tomorrow).overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ]);

        final row = find.text('Sat');
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();

        // A localized reason plus a retry — and no exception text, and no
        // overflow from dropping a full-page error into a list row.
        expect(
          find.textContaining("Couldn't load this day's hours"),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.textContaining('boom'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows dash for humidity when humidity is null',
          (tester) async {
        const current = Weather(
          temperature: 24.0,
          windSpeed: 12.0,
          windDirection: 225.0,
          waveHeight: 0.8,
          description: 'Clear sky',
        );
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(current: current),
          ),
        ]);

        expect(find.text('HUMIDITY'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
      });
    });

    group('no location state', () {
      testWidgets('shows location access message when overview is null',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => null),
        ]);

        expect(
          find.textContaining('Location access is needed'),
          findsOneWidget,
        );
      });

      testWidgets('shows the location-off icon when overview is null',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => null),
        ]);

        expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
      });

      testWidgets('does not show forecast widgets when no location',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => null),
        ]);

        expect(find.byType(HourlyForecastStrip), findsNothing);
        expect(find.byType(DailyForecastList), findsNothing);
      });

      testWidgets('can still be pulled to refresh, to retry after Settings',
          (tester) async {
        // Without this the state is a dead end: the user grants the permission
        // in Settings, comes back, and has no way to ask again.
        var count = 0;
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async {
            count++;
            return null;
          }),
        ]);

        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(count, 1);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 400),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));

        expect(count, greaterThan(1));
      });
    });

    group('loading state', () {
      testWidgets('shows loading indicator while fetching', (tester) async {
        final completer = Completer<WeatherOverview?>();
        addTearDown(() {
          if (!completer.isCompleted) completer.complete(null);
        });
        await tester.pumpWidget(
          buildTestApp(const WeatherScreen(), overrides: [
            weatherOverviewProvider.overrideWith((ref) => completer.future),
          ]),
        );
        await tester.pump();

        expect(find.byIcon(Icons.sailing_rounded), findsOneWidget);
      });
    });

    group('error state', () {
      testWidgets('shows error widget with retry on failure', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => throw Exception('Network error'),
          ),
        ]);

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
        // A localized reason, never the raw exception.
        expect(find.textContaining('Network error'), findsNothing);
        expect(
          find.textContaining("We couldn't load the forecast"),
          findsOneWidget,
        );
      });

      testWidgets('retry reloads and shows data on success', (tester) async {
        var callCount = 0;
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async {
            callCount++;
            if (callCount == 1) throw Exception('First call fails');
            return makeOverview();
          }),
        ]);

        expect(find.text('Something went wrong'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        // Frames, not two 50 ms pumps: the reloaded page enters staggered.
        await pumpFrames(tester, frames: 8);

        expect(find.text('24°'), findsOneWidget);
        expect(find.text('Something went wrong'), findsNothing);
      });
    });

    group('pull-to-refresh', () {
      testWidgets('RefreshIndicator present when loaded', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });

      testWidgets('pull-to-refresh re-invokes the provider', (tester) async {
        var count = 0;
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async {
            count++;
            return makeOverview();
          }),
        ]);

        expect(count, 1);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 400),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));

        expect(count, greaterThan(1));
      });
    });

    group('temperature formatting', () {
      testWidgets('rounds 18.7 to 19 in hero', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async =>
                makeOverview(current: makeWeather(temperature: 18.7)),
          ),
        ]);

        expect(find.text('19°'), findsOneWidget);
      });

      testWidgets('handles zero temperature', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(current: makeWeather(temperature: 0)),
          ),
        ]);

        expect(find.text('0°'), findsOneWidget);
      });

      testWidgets('handles negative temperature', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(current: makeWeather(temperature: -3)),
          ),
        ]);

        expect(find.text('-3°'), findsOneWidget);
      });
    });

    group('the sail window', () {
      testWidgets('wind <= 12 kn and waves <= 0.5 m show good conditions',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            // makeWeather()'s default windSpeed is already the 12 kn boundary.
            (ref) async => makeOverview(
              current: makeWeather(waveHeight: 0.5),
            ),
          ),
        ]);

        expect(find.text('Good conditions to sail'), findsOneWidget);
      });

      testWidgets('wind <= 20 kn and waves <= 1.2 m show moderate conditions',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(
              current: makeWeather(windSpeed: 20, waveHeight: 1.2),
            ),
          ),
        ]);

        expect(find.text('Moderate conditions'), findsOneWidget);
      });

      testWidgets('stronger wind or higher waves show adverse conditions',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(
              current: makeWeather(windSpeed: 21, waveHeight: 1.5),
            ),
          ),
        ]);

        expect(find.text('Adverse conditions'), findsOneWidget);
      });
    });

    /// The finding this phase exists for: the forecast could say the day was
    /// perfect and offer nothing to do about it. The action is not decoration —
    /// it is the reason the tab gets opened.
    group('the sail action', () {
      List<Override> withBoat({
        BoatPermissions permissions = const BoatPermissions.all(),
      }) =>
          [
            weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
            boatsProvider.overrideWith(
              () => FakeBoatsNotifier([makeBoat(permissions: permissions)]),
            ),
          ];

      testWidgets('is offered when there is a boat to sail', (tester) async {
        setPhoneSize(tester);
        await pumpScreen(tester, overrides: withBoat());

        expect(find.text('Start trip'), findsOneWidget);
      });

      testWidgets('is absent with no boat, rather than dead', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        // The verdict still shows: the forecast is worth reading before you
        // own anything.
        expect(find.text('Good conditions to sail'), findsNothing);
        expect(find.text('Moderate conditions'), findsOneWidget);
        expect(find.text('Start trip'), findsNothing);
      });

      testWidgets('is absent for crew who may not record trips',
          (tester) async {
        setPhoneSize(tester);
        await pumpScreen(
          tester,
          overrides: withBoat(
            // Everything except recording: the flag under test is the only
            // one that gates going out.
            permissions: const BoatPermissions(
              canViewDocuments: true,
              canManageDocuments: true,
              canManageMaintenance: true,
              canManageExpenses: true,
            ),
          ),
        );

        // A button that refuses is worse than no button.
        expect(find.text('Start trip'), findsNothing);
        expect(find.text('Moderate conditions'), findsOneWidget);
      });

      testWidgets('says «resume» while a trip is already recording',
          (tester) async {
        setPhoneSize(tester);
        await pumpScreen(tester, overrides: [
          ...withBoat(),
          recordingOverride(),
        ]);

        // Since recording survives leaving the map, «Start trip» while one is
        // running was telling the user to do what they had already done.
        expect(find.text('Resume trip'), findsOneWidget);
        expect(find.text('Start trip'), findsNothing);
      });

      testWidgets('reads its verdict from the shared thresholds',
          (tester) async {
        setPhoneSize(tester);
        // This screen used to carry its own copy of the wind/wave thresholds,
        // so Today and the forecast could disagree about the same weather.
        await pumpScreen(tester, overrides: [
          ...withBoat(),
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(
              current: makeWeather(windSpeed: 8, waveHeight: 0.3),
            ),
          ),
        ]);

        expect(find.text('Good conditions to sail'), findsOneWidget);
        expect(
          find.text('Light wind and a calm sea. Good day to go out.'),
          findsOneWidget,
        );
      });
    });

    group('tides card', () {
      testWidgets('shows high and low tide rows when extremes exist',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(tideExtremes: [
              TideExtreme(
                time: DateTime(2026, 5, 1, 4, 30),
                height: 0.9,
                isHigh: true,
              ),
              TideExtreme(
                time: DateTime(2026, 5, 1, 10, 45),
                height: -0.2,
                isHigh: false,
              ),
            ]),
          ),
        ]);

        expect(find.text('TIDES'), findsOneWidget);
        expect(find.text('High tide'), findsOneWidget);
        expect(find.text('Low tide'), findsOneWidget);
        expect(find.text('04:30'), findsOneWidget);
        expect(find.text('10:45'), findsOneWidget);
      });

      testWidgets('is absent when there are no tide extremes', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.text('TIDES'), findsNothing);
      });
    });

    group('daily forecast fallback', () {
      testWidgets('shows the not-available message when daily is empty',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith(
            (ref) async => makeOverview(daily: const []),
          ),
        ]);

        expect(find.text('Forecast data not available.'), findsOneWidget);
        expect(find.byType(DailyForecastList), findsNothing);
      });
    });

    group('location denied CTA', () {
      testWidgets('Open settings opens the platform location settings',
          (tester) async {
        final fakeGeo = installFakeGeo();
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => null),
        ]);

        await tester.tap(find.text('Open settings'));
        await tester.pump();

        expect(fakeGeo.openSettingsCalled, isTrue);
      });
    });
  });
}
