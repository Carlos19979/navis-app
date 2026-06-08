import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// A horizontally-scrolling strip of hourly forecast cells (iOS-style).
class HourlyForecastStrip extends StatelessWidget {
  const HourlyForecastStrip({super.key, required this.hours});

  final List<HourlyWeather> hours;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : AppColors.textLight;
    final secondary =
        isDark ? context.txtSecondary : AppColors.textLightSecondary;

    return NavisCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: secondary),
                const SizedBox(width: 6),
                Text(
                  l.hourlyForecast.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: context.glassBorderColor.withValues(alpha: 0.3),
            indent: 16,
            endIndent: 16,
          ),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: hours.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) => _HourCell(
                hour: hours[index],
                isNow: index == 0,
                primary: primary,
                secondary: secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.hour,
    required this.isNow,
    required this.primary,
    required this.secondary,
  });

  final HourlyWeather hour;
  final bool isNow;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final condition = WeatherCondition.fromCode(hour.weatherCode);
    final label = isNow ? l.now : DateFormat.j(locale).format(hour.time);
    final precip = hour.precipitationProbability;

    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: secondary,
                  fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Icon(condition.icon, color: condition.color, size: 24),
          SizedBox(
            height: 14,
            child: (precip != null && precip > 0)
                ? Text(
                    '$precip%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            '${hour.temperature.round()}°',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          if (hour.waveHeight != null)
            _MiniStat(
              icon: Icons.waves_rounded,
              value: '${hour.waveHeight!.toStringAsFixed(1)}m',
              color: waveColor(hour.waveHeight!),
            ),
          const SizedBox(height: 3),
          _MiniStat(
            icon: Icons.air_rounded,
            value: '${hour.windSpeed.round()}kt',
            color: windColor(hour.windSpeed),
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
