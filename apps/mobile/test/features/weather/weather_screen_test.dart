import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/forecast_card.dart';

import '../../helpers/test_helpers.dart';

void main() {
  // Disable flutter_animate durations so animations complete instantly
  // in tests, preventing pumpAndSettle timeouts.
  setUpAll(() {
    Animate.restartOnHotReload = false;
  });

  setUp(() {
    // Set animations to zero duration for every test so widgets
    // settle immediately after pump.
    Animate.defaultDuration = Duration.zero;
  });

  tearDown(() {
    Animate.defaultDuration = const Duration(milliseconds: 300);
  });

  group('WeatherScreen', () {
    group('loaded state', () {
      testWidgets('renders without errors when weather data loaded',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith(
                (ref) async => [
                  makeForecast(DateTime(2026, 4, 30)),
                  makeForecast(DateTime(2026, 5)),
                ],
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Screen should be present with no exceptions
        expect(find.byType(WeatherScreen), findsOneWidget);
      });

      testWidgets('shows hero temperature display', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('24°'), findsOneWidget);
      });

      testWidgets('shows weather description', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // makeWeather() description defaults to 'Partly cloudy'
        expect(find.text('Partly cloudy'), findsOneWidget);
      });

      testWidgets('shows wind speed stat pill', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Wind stat pill shows "12 kt"
        expect(find.text('12 kt'), findsAtLeastNWidgets(1));
        expect(find.text('Wind'), findsOneWidget);
      });

      testWidgets('shows wave height stat pill', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // '0.8 m' appears in both the stat pill and WaveChart widget
        expect(find.text('0.8 m'), findsAtLeastNWidgets(1));
        expect(find.text('Waves'), findsOneWidget);
      });

      testWidgets('shows humidity stat pill', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // makeWeather() humidity defaults to 65
        expect(find.text('65%'), findsOneWidget);
        expect(find.text('Humidity'), findsOneWidget);
      });

      testWidgets('shows current conditions card with temperature',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Current Conditions card shows "24.0°C"
        expect(find.text('Current Conditions'), findsOneWidget);
        expect(find.text('24.0°C'), findsOneWidget);
      });

      testWidgets('shows Weather app bar title', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Weather'), findsOneWidget);
      });
    });

    group('no location state', () {
      testWidgets('shows location access message when weather is null',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => null,
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.textContaining('Location access is needed'),
          findsOneWidget,
        );
        expect(
          find.textContaining('for weather data'),
          findsOneWidget,
        );
      });

      testWidgets('shows location_off icon when weather is null',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => null,
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byIcon(Icons.location_off), findsOneWidget);
      });

      testWidgets('does not show temperature or stat pills when no location',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => null,
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Wind'), findsNothing);
        expect(find.text('Waves'), findsNothing);
        expect(find.text('Humidity'), findsNothing);
        expect(find.text('7-Day Forecast'), findsNothing);
      });
    });

    group('loading state', () {
      testWidgets('shows loading indicator while fetching', (tester) async {
        // Use Completers that never complete to keep providers in loading state
        // without leaving pending timers that fail test invariants.
        final weatherCompleter = Completer<Weather?>();
        final forecastCompleter = Completer<List<Weather>>();
        addTearDown(() {
          if (!weatherCompleter.isCompleted) {
            weatherCompleter.complete(null);
          }
          if (!forecastCompleter.isCompleted) {
            forecastCompleter.complete([]);
          }
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) => weatherCompleter.future,
              ),
              forecastProvider.overrideWith(
                (ref) => forecastCompleter.future,
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        // Only pump once to stay in loading state (don't pumpAndSettle)
        await tester.pump();

        // NavisLoading contains a sailing icon inside an animated container
        expect(find.byIcon(Icons.sailing_rounded), findsOneWidget);
      });

      testWidgets('does not show weather data while in loading state',
          (tester) async {
        final weatherCompleter = Completer<Weather?>();
        final forecastCompleter = Completer<List<Weather>>();
        addTearDown(() {
          if (!weatherCompleter.isCompleted) {
            weatherCompleter.complete(null);
          }
          if (!forecastCompleter.isCompleted) {
            forecastCompleter.complete([]);
          }
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) => weatherCompleter.future,
              ),
              forecastProvider.overrideWith(
                (ref) => forecastCompleter.future,
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('24°'), findsNothing);
        expect(find.text('Wind'), findsNothing);
      });
    });

    group('error state', () {
      testWidgets('shows error widget with retry on failure', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => throw Exception('Network error'),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // NavisErrorWidget displays 'Something went wrong' and a Retry button
        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('shows error message from exception', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => throw Exception('Network error'),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.textContaining('Network error'),
          findsOneWidget,
        );
      });

      testWidgets('shows error_outline icon on error', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => throw Exception('fail'),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byIcon(Icons.error_outline_rounded),
          findsOneWidget,
        );
      });

      testWidgets('retry button triggers provider invalidation',
          (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith((ref) async {
                callCount++;
                if (callCount == 1) {
                  throw Exception('First call fails');
                }
                return makeWeather();
              }),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // First render: error state
        expect(find.text('Something went wrong'), findsOneWidget);

        // Tap retry
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        // Extra pump to let zero-duration flutter_animate timers settle
        await tester.pump(const Duration(milliseconds: 50));

        // After retry: weather data should load (second call succeeds)
        expect(find.text('24°'), findsOneWidget);
        expect(find.text('Something went wrong'), findsNothing);
      });
    });

    group('forecast section', () {
      testWidgets('shows 7-Day Forecast header', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith(
                (ref) async => [
                  makeForecast(DateTime(2026, 4, 30)),
                ],
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('7-Day Forecast'), findsOneWidget);
      });

      testWidgets('renders ForecastCard widgets for each forecast day',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith(
                (ref) async => [
                  makeForecast(DateTime(2026, 4, 30)),
                  makeForecast(DateTime(2026, 5)),
                  makeForecast(DateTime(2026, 5, 2)),
                ],
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(ForecastCard), findsOneWidget);
      });

      testWidgets('forecast cards show temperature and wind speed',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith(
                (ref) async => [
                  makeForecast(DateTime(2026, 4, 30)),
                ],
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // makeForecast returns temperature=22, windSpeed=10
        expect(find.text('22°C'), findsOneWidget);
        expect(find.text('10 kt'), findsOneWidget);
      });

      testWidgets('forecast cards show weather description', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith(
                (ref) async => [
                  makeForecast(DateTime(2026, 4, 30)),
                ],
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // makeForecast description defaults to 'Sunny'
        expect(find.text('Sunny'), findsOneWidget);
      });

      testWidgets('empty forecast shows "Forecast data not available." message',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text('Forecast data not available.'),
          findsOneWidget,
        );
      });

      testWidgets('no ForecastCard widgets when forecast is empty',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(ForecastCard), findsNothing);
      });

      testWidgets('forecast error shows error widget with retry',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith(
                (ref) async => throw Exception('Forecast fetch failed'),
              ),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The weather section loads fine, but forecast shows error
        expect(find.text('24°'), findsOneWidget);
        expect(
          find.textContaining('Forecast fetch failed'),
          findsOneWidget,
        );
      });
    });

    group('pull-to-refresh', () {
      testWidgets('pull-to-refresh is functional on the scroll view',
          (tester) async {
        var refreshCount = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith((ref) async {
                refreshCount++;
                return makeWeather();
              }),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify initial load happened
        expect(refreshCount, 1);

        // Perform a drag gesture to trigger RefreshIndicator.
        // fling alone does not reliably trigger the indicator; use
        // drag which holds the pointer long enough to activate it.
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 400),
        );
        await tester.pump();
        // Allow the RefreshIndicator to process the overscroll and
        // call onRefresh
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));

        // After pull-to-refresh, provider should have been invalidated
        // and called again
        expect(refreshCount, greaterThan(1));
      });

      testWidgets('RefreshIndicator is present when weather data is loaded',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });

      testWidgets(
          'RefreshIndicator is absent when weather is null (no location)',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => null,
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(RefreshIndicator), findsNothing);
      });
    });

    group('different temperature values', () {
      testWidgets('rounds temperature to integer for hero display',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(temperature: 18.7),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // 18.7 rounds to 19 with toStringAsFixed(0)
        expect(find.text('19°'), findsOneWidget);
      });

      testWidgets('shows one decimal for conditions card temperature',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(temperature: 18.7),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Current conditions card: toStringAsFixed(1) => "18.7°C"
        expect(find.text('18.7°C'), findsOneWidget);
      });

      testWidgets('handles zero temperature', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(temperature: 0.0),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('0°'), findsOneWidget);
      });

      testWidgets('handles negative temperature', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(temperature: -3.0),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('-3°'), findsOneWidget);
      });
    });

    group('optional weather fields', () {
      testWidgets('hides humidity pill when humidity is null', (tester) async {
        const weatherNoHumidity = Weather(
          temperature: 24.0,
          windSpeed: 12.0,
          windDirection: 225.0,
          waveHeight: 0.8,
          description: 'Clear sky',
          pressure: 1013.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => weatherNoHumidity,
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Wind and Waves should still show
        expect(find.text('Wind'), findsOneWidget);
        expect(find.text('Waves'), findsOneWidget);
        // Humidity should be absent
        expect(find.text('Humidity'), findsNothing);
      });

      testWidgets('shows humidity pill when humidity is present',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentWeatherProvider.overrideWith(
                (ref) async => makeWeather(),
              ),
              forecastProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: WeatherScreen(),
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                Locale('en'),
                Locale('es'),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // makeWeather() has humidity=65
        expect(find.text('Wind'), findsOneWidget);
        expect(find.text('Waves'), findsOneWidget);
        expect(find.text('Humidity'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
      });
    });
  });
}
