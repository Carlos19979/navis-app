import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/utils/status_colors.dart';

/// A horizontally-scrolling strip of hourly forecast cells (iOS-style).
class HourlyForecastStrip extends StatelessWidget {
  const HourlyForecastStrip({
    super.key,
    required this.hours,
    this.embedded = false,
    this.nowLabelled = true,
  });

  final List<HourlyWeather> hours;

  /// Drops the surrounding card and header, for use inside a card that already
  /// provides them — e.g. expanded inside a day of the forecast list, where a
  /// nested card would read as a second panel.
  final bool embedded;

  /// Whether the first cell is labelled "now". True for the rolling 24h that
  /// starts at the current hour; false for a whole other day, whose first cell
  /// is just 00:00.
  final bool nowLabelled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : context.ink;
    final secondary = isDark ? context.txtSecondary : context.inkMuted;

    final strip = SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: hours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) => _HourCell(
          hour: hours[index],
          isNow: nowLabelled && index == 0,
          primary: primary,
          secondary: secondary,
        ),
      ),
    );

    if (embedded) return strip;

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
          strip,
        ],
      ),
    );
  }
}

/// The hour label for a cell, in the locale's own clock convention.
///
/// 12-hour locales come back as "9 AM", which already reads as a time. A
/// 24-hour locale gives a bare number, which read as a list index rather than a
/// clock once a whole day starting at midnight was on screen ("0 1 2 3"), so it
/// is zero-padded to "00 01 02 03".
String _hourLabel(String locale, DateTime time) {
  final formatted = DateFormat.j(locale).format(time);
  final isBareNumber = RegExp(r'^\d+$').hasMatch(formatted);
  return isBareNumber ? formatted.padLeft(2, '0') : formatted;
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
    final label = isNow ? l.now : _hourLabel(locale, hour.time);
    final precip = hour.precipitationProbability;

    return SizedBox(
      // 66, since the units gained their space: at 58 the wind stat sat
      // exactly at the edge and any widening overflowed the cell.
      width: 66,
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
          Icon(condition.icon, color: condition.color(context), size: 24),
          SizedBox(
            height: 14,
            child: (precip != null && precip > 0)
                ? Text(
                    '$precip%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.accent,
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
              value: Measure.waveHeight(locale, hour.waveHeight!),
              color: context.waveColor(hour.waveHeight!),
            ),
          const SizedBox(height: 3),
          _MiniStat(
            icon: Icons.air_rounded,
            value: Measure.windKnots(locale, hour.windSpeed),
            color: context.windColor(hour.windSpeed),
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
        // Shrinks rather than overflows: the string's width depends on the
        // locale's decimal separator and on the user's text scale.
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
