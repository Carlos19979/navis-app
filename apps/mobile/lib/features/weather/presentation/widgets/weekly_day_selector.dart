import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather_overview.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/hourly_forecast_strip.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

/// A horizontal day selector (chips) over a single hourly forecast strip that
/// updates to the selected day. Day 0 (today) reuses the bundled
/// [WeatherOverview.hourly]; later days are fetched via [hourlyForDayProvider].
class WeeklyDaySelector extends ConsumerStatefulWidget {
  const WeeklyDaySelector({super.key, required this.overview});

  final WeatherOverview overview;

  @override
  ConsumerState<WeeklyDaySelector> createState() => _WeeklyDaySelectorState();
}

class _WeeklyDaySelectorState extends ConsumerState<WeeklyDaySelector> {
  int _selected = 0;

  String _weekdayLabel(String locale, DateTime date) =>
      toBeginningOfSentenceCase(DateFormat.E(locale).format(date));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final days = widget.overview.daily;
    final index = _selected.clamp(0, days.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceXs),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: Dimens.spaceSm),
            itemBuilder: (context, i) {
              final day = days[i];
              final label = i == 0 ? l.today : _weekdayLabel(locale, day.date);
              return _DayChip(
                key: ValueKey('weather-day-$i'),
                label: label,
                day: day,
                selected: i == index,
                onTap: () => setState(() => _selected = i),
              );
            },
          ),
        ),
        const SizedBox(height: Dimens.spaceMd),
        _DaySummary(day: days[index], isToday: index == 0),
        const SizedBox(height: Dimens.spaceSm),
        _buildStrip(l, days, index),
      ],
    );
  }

  Widget _buildStrip(AppLocalizations l, List<DailyWeather> days, int index) {
    if (index == 0) {
      final hours = widget.overview.hourly;
      return hours.isEmpty
          ? _EmptyStrip(message: l.forecastNotAvailable)
          : HourlyForecastStrip(hours: hours);
    }

    final date = days[index].date;
    final async = ref.watch(hourlyForDayProvider(date));
    return async.when(
      loading: () => const SizedBox(height: 200, child: NavisLoading()),
      error: (error, _) => SizedBox(
        height: 200,
        child: NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(hourlyForDayProvider(date)),
        ),
      ),
      data: (hours) => hours.isEmpty
          ? _EmptyStrip(message: l.forecastNotAvailable)
          : HourlyForecastStrip(hours: hours),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
    required this.label,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final DailyWeather day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : AppColors.textLight;
    final secondary =
        isDark ? context.txtSecondary : AppColors.textLightSecondary;
    final condition = WeatherCondition.fromCode(day.weatherCode);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: Dimens.spaceSm),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.cyan.withValues(alpha: 0.16)
                : context.glassBg,
            borderRadius: BorderRadius.circular(Dimens.radiusXl),
            border: Border.all(
              color: selected
                  ? AppColors.cyan.withValues(alpha: 0.6)
                  : context.glassBorderColor.withValues(alpha: 0.5),
              width: selected ? 1.2 : 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? primary : secondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Icon(condition.icon, color: condition.color, size: Dimens.iconMd),
              const SizedBox(height: 6),
              Text(
                '${day.temperatureMax.round()}°',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '${day.temperatureMin.round()}°',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact summary (condition, temps, wind, wave) of the selected day, shown
/// above the hourly strip.
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.day, required this.isToday});

  final DailyWeather day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : AppColors.textLight;
    final secondary =
        isDark ? context.txtSecondary : AppColors.textLightSecondary;
    final condition = WeatherCondition.fromCode(day.weatherCode);

    final title = isToday
        ? l.today
        : toBeginningOfSentenceCase(DateFormat.EEEE(locale).format(day.date));
    final dateLabel = DateFormat.MMMMd(locale).format(day.date);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceXs),
      child: Row(
        children: [
          Icon(condition.icon, color: condition.color, size: Dimens.iconLg),
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  '$dateLabel · ${weatherDescription(l, day.weatherCode)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward_rounded, size: 15, color: secondary),
                  Text(
                    '${day.temperatureMax.round()}°',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 15,
                    color: secondary,
                  ),
                  Text(
                    '${day.temperatureMin.round()}°',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: secondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniStat(
                    icon: Icons.air_rounded,
                    value: '${day.windSpeed.round()}kt',
                    color: windColor(day.windSpeed),
                  ),
                  if (day.waveHeight != null) ...[
                    const SizedBox(width: 8),
                    _MiniStat(
                      icon: Icons.waves_rounded,
                      value: '${day.waveHeight!.toStringAsFixed(1)}m',
                      color: waveColor(day.waveHeight!),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      padding: const EdgeInsets.all(Dimens.spaceLg),
      child: Text(message, style: TextStyle(color: context.txtSecondary)),
    );
  }
}
