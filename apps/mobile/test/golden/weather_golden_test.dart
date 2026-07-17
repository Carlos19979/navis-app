@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/screens/weather_screen.dart';

import '../helpers/test_helpers.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadTestFonts);

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
      TideExtreme(time: DateTime(2026, 5, 1, 4, 30), height: 0.9, isHigh: true),
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

  for (final brightness in Brightness.values) {
    testWidgets('weather — ${brightness.name}', (tester) async {
      await pumpGolden(
        tester,
        const WeatherScreen(),
        brightness: brightness,
        settle: false,
        overrides: [
          weatherOverviewProvider.overrideWith((ref) async => overview),
        ],
      );
      await expectLater(
        find.byType(WeatherScreen),
        matchesGoldenFile(goldenPath('weather', brightness)),
      );
    });
  }
}
