import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/day_detail_sheet.dart';

import '../../helpers/test_helpers.dart';

void main() {
  final date = DateTime(2026, 6, 9);

  Widget sheetUnderTest() =>
      Scaffold(body: DayDetailSheet(day: makeDaily(date)));

  group('DayDetailSheet', () {
    testWidgets('shows hourly rows when data is loaded', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          sheetUnderTest(),
          overrides: [
            hourlyForDayProvider(date).overrideWith(
              (ref) async => [
                makeHourly(DateTime(2026, 6, 9, 9), temperature: 21),
                makeHourly(DateTime(2026, 6, 9, 15), temperature: 25),
              ],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(DayDetailSheet), findsOneWidget);
      // Hourly temperatures
      expect(find.text('21°'), findsOneWidget);
      expect(find.text('25°'), findsOneWidget);
      // Wave value from makeHourly default (0.5)
      expect(find.text('0.5 m'), findsWidgets);
    });

    testWidgets('shows loading indicator while fetching', (tester) async {
      final completer = Completer<List<HourlyWeather>>();
      addTearDown(() {
        if (!completer.isCompleted) completer.complete([]);
      });
      await tester.pumpWidget(
        buildTestApp(
          sheetUnderTest(),
          overrides: [
            hourlyForDayProvider(date).overrideWith((ref) => completer.future),
          ],
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sailing_rounded), findsOneWidget);
    });

    testWidgets('shows error widget on failure', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          sheetUnderTest(),
          overrides: [
            hourlyForDayProvider(date).overrideWith(
              (ref) async => throw Exception('Hourly fetch failed'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows empty message when no hourly data', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          sheetUnderTest(),
          overrides: [
            hourlyForDayProvider(date).overrideWith((ref) async => []),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Forecast data not available.'), findsOneWidget);
    });
  });
}
