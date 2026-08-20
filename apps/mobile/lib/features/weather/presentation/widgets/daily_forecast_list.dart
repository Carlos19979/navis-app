import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/daily_weather.dart';
import 'package:navis_mobile/features/weather/domain/entities/hourly_weather.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/hourly_forecast_strip.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_inline_error.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/utils/status_colors.dart';

/// The week's forecast as a vertical list of days with temperature range bars,
/// where tapping a day expands its hourly detail in place (iOS-style).
///
/// One day is open at a time. Today's hours come bundled with the overview;
/// later days are fetched on demand the first time they are opened, and cached
/// by [hourlyForDayProvider] so reopening one is instant.
class DailyForecastList extends ConsumerStatefulWidget {
  const DailyForecastList({
    super.key,
    required this.days,
    this.todayHours = const [],
    this.initiallyExpanded,
  });

  final List<DailyWeather> days;

  /// Hours for day 0, already loaded as part of the weather overview.
  final List<HourlyWeather> todayHours;

  /// Index of the day open on first build. Null means all collapsed.
  final int? initiallyExpanded;

  @override
  ConsumerState<DailyForecastList> createState() => _DailyForecastListState();
}

class _DailyForecastListState extends ConsumerState<DailyForecastList> {
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggle(int index) {
    setState(() => _expanded = _expanded == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();

    // Temperature span across the whole week, so every range bar is drawn on
    // the same scale and the days are comparable at a glance.
    var globalMin = days.first.temperatureMin;
    var globalMax = days.first.temperatureMax;
    for (final day in days) {
      globalMin = math.min(globalMin, day.temperatureMin);
      globalMax = math.max(globalMax, day.temperatureMax);
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
              expanded: _expanded == i,
              globalMin: globalMin,
              globalMax: globalMax,
              onTap: () => _toggle(i),
            ),
            // AnimatedSize gives the accordion its open/close motion without a
            // separate controller per row.
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.curve,
              alignment: Alignment.topCenter,
              child: _expanded == i
                  ? _DayHours(
                      day: days[i],
                      isToday: i == 0,
                      todayHours: widget.todayHours)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

/// The expanded day's hourly detail. Today reuses the hours already bundled in
/// the overview; any other day is fetched on demand.
class _DayHours extends ConsumerWidget {
  const _DayHours({
    required this.day,
    required this.isToday,
    required this.todayHours,
  });

  final DailyWeather day;
  final bool isToday;
  final List<HourlyWeather> todayHours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    if (isToday) {
      return _wrap(
        todayHours.isEmpty
            ? _Message(text: l.forecastNotAvailable)
            : HourlyForecastStrip(hours: todayHours, embedded: true),
      );
    }

    final provider = hourlyForDayProvider(day.date);
    return _wrap(
      switch (ref.watch(provider)) {
        AsyncLoading() => const Padding(
            padding: EdgeInsets.symmetric(vertical: Dimens.spaceXl),
            child: NavisLoading(),
          ),
        // The reason is deliberately generic and localized: a raw exception
        // string is neither meaningful to the user nor safe to render in a
        // fixed-height slot.
        AsyncError() => NavisInlineError(
            message: l.hourlyLoadFailed,
            onRetry: () => ref.invalidate(provider),
          ),
        // A future day starts at 00:00, so nothing here is "now".
        AsyncValue(hasValue: true, :final value?) => value.isEmpty
            ? _Message(text: l.forecastNotAvailable)
            : HourlyForecastStrip(
                hours: value,
                embedded: true,
                nowLabelled: false,
              ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _wrap(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: Dimens.spaceSm),
      child: child,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spaceLg,
        vertical: Dimens.spaceMd,
      ),
      child: Text(text, style: TextStyle(color: context.txtSecondary)),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.day,
    required this.isToday,
    required this.expanded,
    required this.globalMin,
    required this.globalMax,
    required this.onTap,
  });

  final DailyWeather day;
  final bool isToday;
  final bool expanded;
  final double globalMin;
  final double globalMax;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : context.ink;
    final secondary = isDark ? context.txtSecondary : context.inkMuted;
    final condition = WeatherCondition.fromCode(day.weatherCode);

    final label = isToday
        ? l.today
        : toBeginningOfSentenceCase(DateFormat.E(locale).format(day.date));

    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      child: InkWell(
        onTap: onTap,
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
              Icon(condition.icon, color: condition.color(context), size: 22),
              const SizedBox(width: 10),
              SizedBox(
                // Wider since the units gained their space ("9 kt", not
                // "9kt"): the old 58 was exactly the width of the un-spaced
                // string and overflowed the moment it grew.
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniStat(
                      icon: Icons.air_rounded,
                      value: Measure.windKnots(locale, day.windSpeed),
                      color: context.windColor(day.windSpeed),
                    ),
                    if (day.waveHeight != null) ...[
                      const SizedBox(height: 2),
                      _MiniStat(
                        icon: Icons.waves_rounded,
                        value: Measure.waveHeight(locale, day.waveHeight!),
                        color: context.waveColor(day.waveHeight!),
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
              const SizedBox(width: 4),
              // Rotates to point down when the day is open, so the row reads as
              // a disclosure rather than a link to somewhere else.
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: Motion.fast,
                curve: Motion.curve,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: expanded
                      ? context.accent
                      : secondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
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
                    gradient: LinearGradient(
                      colors: [context.accent, context.caution],
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
        // Shrinks rather than overflows: this sits in a fixed-width column and
        // the string's length depends on the locale's decimal separator and on
        // the user's text scale.
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
