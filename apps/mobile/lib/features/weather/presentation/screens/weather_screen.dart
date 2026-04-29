import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/forecast_card.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/wave_chart.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/wind_indicator.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWeather = ref.watch(currentWeatherProvider);
    final forecast = ref.watch(forecastProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const NavisAppBar(title: 'Weather', transparent: true),
      body: GradientBackground(
        child: currentWeather.when(
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppColors.glassWhite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.glassBorder,
                          ),
                        ),
                        child: Icon(
                          Icons.location_off,
                          size: 40,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Location access is needed\nfor weather data.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.cyan,
              backgroundColor: const Color(0xFF1B2A4A),
              onRefresh: () async {
                ref.invalidate(currentWeatherProvider);
                ref.invalidate(forecastProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  kToolbarHeight + MediaQuery.of(context).padding.top + 16,
                  16,
                  100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero temperature
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '${weather.temperature.toStringAsFixed(0)}°',
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w200,
                                  fontSize: 96,
                                  height: 1.0,
                                ),
                          ).animate().fadeIn(duration: 600.ms).slideY(
                                begin: -0.1,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              ),
                          const SizedBox(height: 4),
                          Text(
                            weather.description,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                          ).animate().fadeIn(
                                delay: 200.ms,
                                duration: 500.ms,
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Current conditions card
                    NavisCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Current Conditions',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${weather.temperature.toStringAsFixed(1)}°C',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: AppColors.glassBorder,
                          ),
                          Expanded(
                            child: Center(
                              child: WindIndicator(
                                direction: weather.windDirection,
                                speed: weather.windSpeed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                          delay: 300.ms,
                          duration: 500.ms,
                        ),
                    const SizedBox(height: 12),

                    // Weather stats row (glass pills)
                    Row(
                      children: [
                        Expanded(
                          child: _WeatherStatPill(
                            icon: Icons.air,
                            label: 'Wind',
                            value:
                                '${weather.windSpeed.toStringAsFixed(0)} kt',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _WeatherStatPill(
                            icon: Icons.waves,
                            label: 'Waves',
                            value:
                                '${weather.waveHeight.toStringAsFixed(1)} m',
                          ),
                        ),
                        if (weather.humidity != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _WeatherStatPill(
                              icon: Icons.water_drop,
                              label: 'Humidity',
                              value: '${weather.humidity}%',
                            ),
                          ),
                        ],
                      ],
                    ).animate().fadeIn(
                          delay: 400.ms,
                          duration: 500.ms,
                        ),
                    const SizedBox(height: 16),

                    // Wave chart
                    WaveChart(waveHeight: weather.waveHeight)
                        .animate()
                        .fadeIn(
                          delay: 500.ms,
                          duration: 500.ms,
                        ),
                    const SizedBox(height: 24),

                    // Forecast header
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '7-Day Forecast',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Forecast list
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
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (int i = 0; i < days.length; i++)
                              ForecastCard(weather: days[i])
                                  .animate()
                                  .fadeIn(
                                    delay: (600 + i * 80).ms,
                                    duration: 400.ms,
                                  )
                                  .slideX(
                                    begin: 0.05,
                                    end: 0,
                                    delay: (600 + i * 80).ms,
                                    duration: 400.ms,
                                    curve: Curves.easeOut,
                                  ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WeatherStatPill extends StatelessWidget {
  const _WeatherStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      opacity: 0.06,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.cyan, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
