import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/daily_forecast_list.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/day_detail_sheet.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/hourly_forecast_strip.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/wind_indicator.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final overview = ref.watch(weatherOverviewProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(title: l.weather, transparent: true),
      body: GradientBackground(
        child: overview.when(
          loading: () => const NavisLoading(),
          error: (error, stack) => NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(weatherOverviewProvider),
          ),
          data: (data) {
            if (data == null) {
              return _LocationDenied(message: l.locationAccessNeeded);
            }
            return RefreshIndicator(
              color: AppColors.cyan,
              backgroundColor: context.dialogSurface,
              onRefresh: () async {
                // Re-acquire GPS too, not just the weather, so a stale or
                // wrong location actually updates.
                ref.invalidate(positionProvider);
                ref.invalidate(weatherOverviewProvider);
              },
              child: _OverviewBody(overview: data),
            );
          },
        ),
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.overview});

  final WeatherOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : AppColors.textLight;
    final secondary =
        isDark ? context.txtSecondary : AppColors.textLightSecondary;

    final current = overview.current;
    final today = overview.daily.isNotEmpty ? overview.daily.first : null;
    final condition = WeatherCondition.fromCode(current.weatherCode);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        kToolbarHeight + MediaQuery.of(context).padding.top + 8,
        16,
        100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero: icon, temperature, description, today's high/low.
          Center(
            child: Column(
              children: [
                Icon(condition.icon, color: condition.color, size: 52)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 4),
                Text(
                  '${current.temperature.round()}°',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w200,
                        fontSize: 92,
                        height: 1.0,
                      ),
                ).animate().fadeIn(duration: 600.ms).slideY(
                      begin: -0.1,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 2),
                Text(
                  weatherDescription(l, current.weatherCode),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: secondary,
                        letterSpacing: 0.5,
                      ),
                ).animate().fadeIn(delay: 150.ms, duration: 500.ms),
                if (today != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward_rounded,
                          size: 15, color: secondary),
                      Text(
                        '${today.temperatureMax.round()}°',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.arrow_downward_rounded,
                          size: 15, color: secondary),
                      Text(
                        '${today.temperatureMin.round()}°',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: secondary,
                            ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Hourly strip (next 24h).
          if (overview.hourly.isNotEmpty)
            HourlyForecastStrip(hours: overview.hourly).animate().fadeIn(
                  delay: 300.ms,
                  duration: 500.ms,
                ),
          const SizedBox(height: 12),

          // Current conditions detail card.
          _CurrentDetailsCard(overview: overview).animate().fadeIn(
                delay: 400.ms,
                duration: 500.ms,
              ),
          const SizedBox(height: 12),

          // Navigation window suitability (from wind + waves).
          _NavWindowBadge(overview: overview).animate().fadeIn(
                delay: 450.ms,
                duration: 400.ms,
              ),

          // Tides (high/low), when available.
          if (overview.tideExtremes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TidesCard(extremes: overview.tideExtremes).animate().fadeIn(
                  delay: 480.ms,
                  duration: 400.ms,
                ),
          ],
          const SizedBox(height: 24),

          // Daily forecast.
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              l.sevenDayForecast,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (overview.daily.isNotEmpty)
            DailyForecastList(
              days: overview.daily,
              onDayTap: (day) => showDayDetailSheet(context, day),
            ).animate().fadeIn(
                  delay: 500.ms,
                  duration: 400.ms,
                )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.forecastNotAvailable,
                style: TextStyle(color: secondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentDetailsCard extends StatelessWidget {
  const _CurrentDetailsCard({required this.overview});

  final WeatherOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final current = overview.current;

    return NavisCard(
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: WindIndicator(
                direction: current.windDirection,
                speed: current.windSpeed,
              ),
            ),
          ),
          Container(width: 1, height: 70, color: context.glassBorderColor),
          Expanded(
            child: Column(
              children: [
                _DetailPill(
                  icon: Icons.waves_rounded,
                  label: l.waves,
                  value: '${current.waveHeight.toStringAsFixed(1)} m',
                  color: waveColor(current.waveHeight),
                ),
                const SizedBox(height: 8),
                _DetailPill(
                  icon: Icons.water_drop_rounded,
                  label: l.humidity,
                  value:
                      current.humidity != null ? '${current.humidity}%' : '—',
                  color: AppColors.cyan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : AppColors.textLight;
    final secondary =
        isDark ? context.txtSecondary : AppColors.textLightSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: secondary,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationDenied extends StatelessWidget {
  const _LocationDenied({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
                color: context.glassBg,
                shape: BoxShape.circle,
                border: Border.all(color: context.glassBorderColor),
              ),
              child: Icon(
                Icons.location_off,
                size: 40,
                color: context.txtSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.txtSecondary),
            ),
            const SizedBox(height: 24),
            NavisButton(
              label: AppLocalizations.of(context)!.openSettings,
              icon: Icons.settings_outlined,
              variant: NavisButtonVariant.secondary,
              compact: true,
              onPressed: Geolocator.openLocationSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// A "good to sail" indicator based on current wind and wave conditions.
class _NavWindowBadge extends StatelessWidget {
  const _NavWindowBadge({required this.overview});

  final WeatherOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final wind = overview.current.windSpeed;
    final wave = overview.current.waveHeight;

    final (color, label, icon) = switch (null) {
      _ when wind <= 12 && wave <= 0.5 => (
          AppColors.green,
          l.sailConditionsGood,
          Icons.check_circle,
        ),
      _ when wind <= 20 && wave <= 1.2 => (
          AppColors.amber,
          l.sailConditionsModerate,
          Icons.info,
        ),
      _ => (
          AppColors.red,
          l.sailConditionsAdverse,
          Icons.warning_amber_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l.windWavesSummary(
                    wind.round().toString(),
                    wave.toStringAsFixed(1),
                  ),
                  style: TextStyle(color: context.txtSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upcoming high/low tides.
class _TidesCard extends StatelessWidget {
  const _TidesCard({required this.extremes});

  final List<TideExtreme> extremes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    // Carrera = how much the water rises and falls = highest − lowest.
    final heights = extremes.map((e) => e.height).toList();
    final range = heights.isEmpty
        ? 0.0
        : heights.reduce((a, b) => a > b ? a : b) -
            heights.reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.glassBorderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waves, color: AppColors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                l.tides,
                style: TextStyle(
                  color: context.txtPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                l.tideRange(range.toStringAsFixed(1)),
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in extremes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    e.isHigh ? Icons.arrow_upward : Icons.arrow_downward,
                    color: e.isHigh ? AppColors.cyan : AppColors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.isHigh ? l.tideHigh : l.tideLow,
                    style: TextStyle(color: context.txtPrimary),
                  ),
                  const Spacer(),
                  Text(
                    hhmm(e.time),
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${e.height >= 0 ? '+' : ''}${e.height.toStringAsFixed(1)} m',
                    style: TextStyle(color: context.txtSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
