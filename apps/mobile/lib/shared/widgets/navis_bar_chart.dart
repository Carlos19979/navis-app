import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// One column of a [NavisBarChart].
@immutable
final class NavisBar {
  const NavisBar({
    required this.label,
    required this.value,
    this.valueLabel,
    this.semanticsLabel,
    this.onTap,
    this.highlighted = false,
  });

  /// Axis label under the bar — already localized and short.
  final String label;

  /// Height driver. Must not be negative.
  final double value;

  /// Printed above the bar when there is a value. Null hides it.
  final String? valueLabel;

  /// Spoken instead of "label: valueLabel" — for the context the axis label has
  /// no room for, such as which year the month belongs to.
  final String? semanticsLabel;

  /// Drill-down. Null (or a zero [value]) makes the column inert.
  final VoidCallback? onTap;

  /// Draws the column in the accent even when it is not the tallest — used to
  /// mark the currently selected slice.
  final bool highlighted;
}

/// A row of proportional bars: the app's chart, drawn with plain widgets.
///
/// Navis ships no charting package on purpose — this and a dashed border are the
/// only drawing the app does, and a `Container` with a gradient is cheaper and
/// more themeable than a painter. Extracted from the two `_MonthlyChart` copies
/// (logbook statistics and cost intelligence) that had drifted: only one of them
/// labelled its values, was tappable, or was reachable with a screen reader.
class NavisBarChart extends StatelessWidget {
  const NavisBarChart({
    super.key,
    required this.bars,
    this.title,
    this.barHeight = 60,
    this.averageValue,
    this.averageLabel,
  });

  final List<NavisBar> bars;

  /// Optional heading inside the card.
  final String? title;

  /// Height of the tallest bar, in logical pixels.
  final double barHeight;

  /// Draws a dashed reference line at this value — the period's average.
  final double? averageValue;

  /// Spoken and shown next to the average line.
  final String? averageLabel;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final maxValue = bars.fold<double>(
      0,
      (m, b) => b.value > m ? b.value : m,
    );
    // Everything at zero: draw the baseline stubs rather than dividing by it.
    final scale = maxValue > 0 ? maxValue : 1.0;

    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: Dimens.spaceLg),
          ],
          if (averageValue != null && averageLabel != null) ...[
            _AverageLegend(label: averageLabel!),
            const SizedBox(height: Dimens.spaceSm),
          ],
          RepaintBoundary(
            child: SizedBox(
              // Room for the value label, the bar and the axis label.
              height: barHeight + 48,
              child: Stack(
                children: [
                  if (averageValue != null && maxValue > 0)
                    _AverageLine(
                      fraction: (averageValue! / scale).clamp(0.0, 1.0),
                      barHeight: barHeight,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final bar in bars)
                        Expanded(
                          child: _Column(
                            bar: bar,
                            scale: scale,
                            barHeight: barHeight,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.bar,
    required this.scale,
    required this.barHeight,
  });

  final NavisBar bar;
  final double scale;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final hasValue = bar.value > 0;
    final tappable = hasValue && bar.onTap != null;
    final accent = bar.highlighted || hasValue;

    return Semantics(
      button: tappable,
      selected: bar.highlighted,
      label: bar.semanticsLabel ??
          '${bar.label}: ${bar.valueLabel ?? bar.value.toStringAsFixed(0)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: tappable ? bar.onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasValue && bar.valueLabel != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    bar.valueLabel!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9,
                      color: context.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Container(
                height: (bar.value / scale * barHeight).clamp(4.0, barHeight),
                decoration: BoxDecoration(
                  gradient: accent ? context.accentGradient : null,
                  color: accent
                      ? null
                      : context.txtSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: bar.highlighted
                      ? Border.all(color: context.accent, width: 1.5)
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  bar.label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, color: context.txtSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The average reference line, sitting behind the bars.
class _AverageLine extends StatelessWidget {
  const _AverageLine({required this.fraction, required this.barHeight});

  final double fraction;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    // The bars grow from the axis labels upward, so the line is measured from
    // the same baseline: 18px of axis label below it.
    return Positioned(
      left: 0,
      right: 0,
      bottom: 18 + barHeight * fraction,
      child: Container(
        height: 1,
        color: context.txtSecondary.withValues(alpha: 0.35),
      ),
    );
  }
}

class _AverageLegend extends StatelessWidget {
  const _AverageLegend({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 1,
          color: context.txtSecondary.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.txtSecondary,
              ),
        ),
      ],
    );
  }
}
