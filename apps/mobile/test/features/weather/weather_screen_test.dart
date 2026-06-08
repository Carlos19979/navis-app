import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/daily_forecast_list.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/day_detail_sheet.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/hourly_forecast_strip.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/wind_indicator.dart';

import '../../helpers/test_helpers.dart';

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
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

      testWidgets('shows hourly forecast strip', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(HourlyForecastStrip), findsOneWidget);
      });

      testWidgets('shows daily forecast list', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(DailyForecastList), findsOneWidget);
      });

      testWidgets('shows wind indicator, waves and humidity in details card',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.byType(WindIndicator), findsOneWidget);
        expect(find.text('Waves'), findsOneWidget);
        expect(find.text('Humidity'), findsOneWidget);
        // makeWeather() waveHeight 0.8, humidity 65
        expect(find.text('0.8 m'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
      });

      testWidgets('shows 7-Day Forecast header', (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
        ]);

        expect(find.text('7-Day Forecast'), findsOneWidget);
      });

      testWidgets('tapping a day opens the hourly detail sheet',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => makeOverview()),
          // makeOverview()'s single day is dated 2026-05-01.
          hourlyForDayProvider(DateTime(2026, 5)).overrideWith(
            (ref) async => [makeHourly(DateTime(2026, 5, 1, 10))],
          ),
        ]);

        // 'Today' is the tappable label of the first daily row; it sits below
        // the fold, so scroll it into view before tapping.
        await tester.ensureVisible(find.text('Today'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Today'));
        await tester.pumpAndSettle();

        expect(find.byType(DayDetailSheet), findsOneWidget);
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

        expect(find.text('Humidity'), findsOneWidget);
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

      testWidgets('shows location_off icon when overview is null',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => null),
        ]);

        expect(find.byIcon(Icons.location_off), findsOneWidget);
      });

      testWidgets('does not show forecast widgets when no location',
          (tester) async {
        await pumpScreen(tester, overrides: [
          weatherOverviewProvider.overrideWith((ref) async => null),
        ]);

        expect(find.byType(HourlyForecastStrip), findsNothing);
        expect(find.byType(DailyForecastList), findsNothing);
        expect(find.byType(RefreshIndicator), findsNothing);
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
        expect(find.textContaining('Network error'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

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
  });
}
