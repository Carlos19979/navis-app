import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// A vertical list of daily forecasts with temperature range bars (iOS-style).
class DailyForecastList extends StatelessWidget {
  const DailyForecastList({super.key, required this.days, this.onDayTap});

  final List<DailyWeather> days;
  final void Function(DailyWeather day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    // Global temperature span for normalizing the range bars.
    var globalMin = days.first.temperatureMin;
    var globalMax = days.first.temperatureMax;
    for (final d in days) {
      globalMin = math.min(globalMin, d.temperatureMin);
      globalMax = math.max(globalMax, d.temperatureMax);
    }

    return NavisCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: context.glassBorderColor.withValues(alpha: 0.3),
                indent: 16,
                endIndent: 16,
              ),
            _DailyRow(
              day: days[i],
              isToday: i == 0,
              globalMin: globalMin,
              globalMax: globalMax,
              onTap: onDayTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.day,
    required this.isToday,
    required this.globalMin,
    required this.globalMax,
    this.onTap,
  });

  final DailyWeather day;
  final bool isToday;
  final double globalMin;
  final double globalMax;
  final void Function(DailyWeather day)? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : AppColors.textLight;
    final secondary =
        isDark ? context.txtSecondary : AppColors.textLightSecondary;
    final condition = WeatherCondition.fromCode(day.weatherCode);

    final label = isToday
        ? l.today
        : toBeginningOfSentenceCase(DateFormat.E(locale).format(day.date));

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(day),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Icon(condition.icon, color: condition.color, size: 22),
            const SizedBox(width: 10),
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniStat(
                    icon: Icons.air_rounded,
                    value: '${day.windSpeed.round()}kt',
                    color: windColor(day.windSpeed),
                  ),
                  if (day.waveHeight != null) ...[
                    const SizedBox(height: 2),
                    _MiniStat(
                      icon: Icons.waves_rounded,
                      value: '${day.waveHeight!.toStringAsFixed(1)}m',
                      color: waveColor(day.waveHeight!),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${day.temperatureMin.round()}°',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: secondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TempRangeBar(
                min: day.temperatureMin,
                max: day.temperatureMax,
                globalMin: globalMin,
                globalMax: globalMax,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${day.temperatureMax.round()}°',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: secondary.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TempRangeBar extends StatelessWidget {
  const _TempRangeBar({
    required this.min,
    required this.max,
    required this.globalMin,
    required this.globalMax,
  });

  final double min;
  final double max;
  final double globalMin;
  final double globalMax;

  @override
  Widget build(BuildContext context) {
    final span = math.max(globalMax - globalMin, 1.0);
    final leftFrac = ((min - globalMin) / span).clamp(0.0, 1.0);
    final rightFrac = ((max - globalMin) / span).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final left = leftFrac * width;
        final segWidth = math.max((rightFrac - leftFrac) * width, 6.0);

        return SizedBox(
          height: 6,
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: context.glassBorderColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: left,
                child: Container(
                  height: 6,
                  width: segWidth,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.cyan, AppColors.amber],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
