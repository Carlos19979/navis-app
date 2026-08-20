import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/features/weather/presentation/widgets/weather_visuals.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/utils/status_colors.dart';

/// Current conditions as a grid of metric tiles, Apple-Weather style: one wide
/// tile for wind and a pair of smaller ones below.
///
/// This replaces the old compass dial. A rotating needle looked like an
/// instrument but read as decoration — it took a quarter of the card to say
/// what "NW 315°" says in a line, and it left the numbers (speed, waves,
/// humidity) cramped into pills beside it. Every tile now has the same
/// anatomy — label, value, and a gauge showing where the value sits on its
/// scale — so the card can be scanned down a single column.
class CurrentConditions extends StatelessWidget {
  const CurrentConditions({super.key, required this.current});

  final Weather current;

  /// Gauge full-scale ends. Above these the bar just pins full: 40 kt and 4 m
  /// are already "stay in port", so the exact overshoot changes no decision.
  static const _windFullScale = 40.0;
  static const _waveFullScale = 4.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final wind = current.windSpeed;
    final wave = current.waveHeight;

    return Column(
      children: [
        _MetricTile(
          icon: Icons.air_rounded,
          label: l.wind,
          value: wind.round().toString(),
          unit: 'kt',
          color: context.windColor(wind),
          fraction: wind / _windFullScale,
          grade: windScaleLabel(l, wind),
          // Direction as type, not as a dial: the cardinal is what gets said
          // out loud on board, the degrees are for the plotter.
          trailing: '${cardinalDirection(l, current.windDirection)}  '
              '${current.windDirection.round()}°',
        ),
        const SizedBox(height: Dimens.spaceMd),
        // Equal-height tiles whatever the text scale does to their labels.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.waves_rounded,
                  label: l.waves,
                  value: wave.toStringAsFixed(1),
                  unit: 'm',
                  color: context.waveColor(wave),
                  fraction: wave / _waveFullScale,
                  grade: waveScaleLabel(l, wave),
                ),
              ),
              const SizedBox(width: Dimens.spaceMd),
              Expanded(
                child: _MetricTile(
                  icon: Icons.water_drop_rounded,
                  label: l.humidity,
                  value: current.humidity?.toString() ?? '—',
                  unit: current.humidity != null ? '%' : '',
                  color: context.accent,
                  fraction: (current.humidity ?? 0) / 100,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One metric: uppercase label, the value large, and a gauge for the scale.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.fraction,
    this.grade,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  /// Position on the metric's scale, 0..1. Clamped when painted.
  final double fraction;

  /// Qualitative reading of [value] (calm / moderate / rough) for screen
  /// readers, when the metric has one. Deliberately not drawn: the gauge color
  /// already carries the grading, and the sailing-conditions badge below the
  /// grid says it in words — printing it per tile said "moderate" three times
  /// on one screen.
  final String? grade;

  /// Extra reading shown top-right — wind direction, for the wind tile.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    // Same convention as the rest of the screen: over the light gradient the
    // dark-only text tokens do not have the contrast.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? context.txtPrimary : context.ink;
    final secondary = isDark ? context.txtSecondary : context.inkMuted;
    final text = Theme.of(context).textTheme;

    return Semantics(
      // One node per tile: read as "wind 12 kt, moderate, SW 225" instead of
      // as four loose fragments, and the grade word — which the visual leaves
      // to the gauge color — reaches a screen reader here.
      container: true,
      label: '$label $value $unit${grade != null ? ', $grade' : ''}'
          '${trailing != null ? ', $trailing' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Dimens.spaceLg),
        decoration: BoxDecoration(
          color: context.glassBg,
          borderRadius: BorderRadius.circular(Dimens.radiusXl),
          border: Border.all(color: context.glassBorderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: secondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (trailing case final String t)
                  Text(
                    t,
                    style: text.labelMedium?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Dimens.spaceMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: text.headlineMedium?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: text.titleSmall?.copyWith(color: secondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Dimens.spaceMd),
            _MetricGauge(fraction: fraction, color: color),
          ],
        ),
      ),
    );
  }
}

/// A hairline scale bar: track for the full range, a fill for where we are.
class _MetricGauge extends StatelessWidget {
  const _MetricGauge({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimens.radiusPill),
      child: Container(
        height: 4,
        color: context.glassBorderColor,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          // A hair of fill even at zero, so the bar reads as a scale rather
          // than as an empty line the layout forgot to fill.
          widthFactor: fraction.clamp(0.02, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.45), color],
              ),
              borderRadius: BorderRadius.circular(Dimens.radiusPill),
            ),
          ),
        ),
      ),
    );
  }
}
