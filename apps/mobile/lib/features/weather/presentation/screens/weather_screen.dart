import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/forecast_card.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/wave_chart.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/wind_indicator.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWeather = ref.watch(currentWeatherProvider);
    final forecast = ref.watch(forecastProvider);

    return Scaffold(
      appBar: const NavisAppBar(title: 'Weather'),
      body: currentWeather.when(
        loading: () => const NavisLoading(),
        error: (error, stack) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(currentWeatherProvider);
            ref.invalidate(forecastProvider);
          },
        ),
        data: (weather) {
          if (weather == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Location access is needed for weather data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.cyan,
            onRefresh: () async {
              ref.invalidate(currentWeatherProvider);
              ref.invalidate(forecastProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Current Conditions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${weather.temperature.toStringAsFixed(0)}°C',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(color: AppColors.cyan),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    weather.description,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              WindIndicator(
                                direction: weather.windDirection,
                                speed: weather.windSpeed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _WeatherStat(
                                icon: Icons.air,
                                label: 'Wind',
                                value:
                                    '${weather.windSpeed.toStringAsFixed(0)} kt',
                              ),
                              _WeatherStat(
                                icon: Icons.waves,
                                label: 'Waves',
                                value:
                                    '${weather.waveHeight.toStringAsFixed(1)} m',
                              ),
                              if (weather.humidity != null)
                                _WeatherStat(
                                  icon: Icons.water_drop,
                                  label: 'Humidity',
                                  value: '${weather.humidity}%',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  WaveChart(waveHeight: weather.waveHeight),
                  const SizedBox(height: 24),
                  Text(
                    '7-Day Forecast',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  forecast.when(
                    loading: () => const NavisLoading(),
                    error: (error, stack) => NavisErrorWidget(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(forecastProvider),
                    ),
                    data: (days) {
                      if (days.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Forecast data not available.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return Column(
                        children: days
                            .map((day) => ForecastCard(weather: day))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
