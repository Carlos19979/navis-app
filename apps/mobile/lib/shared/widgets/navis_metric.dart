import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// One figure with its label — the block the statistics screens are built from.
///
/// Was duplicated as `_StatCard` (logbook statistics) and `_Kpi` (cost
/// intelligence), which had drifted apart: one scaled with the type scale and
/// had an icon, the other hard-coded `fontSize: 22` and had none.
///
/// Editorial treatment: the figure leads, in tabular numerals so a column of
/// them aligns and none of them jitters as the data updates. No card and no
/// tinted icon disc — a grid of six discs was six competing focal points, and
/// the figure is the thing worth looking at. The icon, when a caller passes
/// one, rides small and quiet next to the label.
class NavisMetric extends StatelessWidget {
  const NavisMetric({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.semanticValue,
  });

  /// The figure, already formatted — `'—'` when there is nothing to show.
  final String value;
  final String label;

  final IconData? icon;

  /// Tints the figure. Pass a semantic accent (text role); defaults to plain
  /// ink, which is usually right — colour should mean something.
  final Color? color;

  /// Spoken instead of [value] when the compact form would not read well
  /// ("9 €/MN" for "€/MN 9"). Defaults to `label: value`.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticValue ?? '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scales down rather than overflowing at large text sizes, instead of
          // overriding the type scale with a fixed fontSize.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: NavisType.title1.copyWith(color: color ?? context.ink),
            ),
          ),
          const SizedBox(height: Dimens.spaceXs),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: context.inkFaint),
                const SizedBox(width: Dimens.spaceXs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: NavisType.caption.copyWith(color: context.inkMuted),
                  // Two lines, not one: at three columns a phone gives each
                  // label ~110px, and "Combustible / MN" or "Coste / h motor"
                  // ellipsized down to "Combustibl…", which names nothing.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lays [children] out in [columns] per row, divided by hairlines.
///
/// Padding the last row keeps the blocks at their column width instead of
/// stretching the survivors across the gap.
class NavisMetricGrid extends StatelessWidget {
  const NavisMetricGrid({
    super.key,
    required this.children,
    this.columns = 3,
  });

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final end = (i + columns).clamp(0, children.length);
      final slice = children.sublist(i, end);
      // No CrossAxisAlignment.stretch: inside a ListView the row's height is
      // unbounded and stretching asks children for an infinite height.
      rows.add(
        Row(
          children: [
            for (var j = 0; j < columns; j++) ...[
              // Only between two real figures: a last row with one metric in it
              // was drawing a rule against an empty cell, which read as a
              // missing value rather than as no value.
              if (j > 0 && j < slice.length)
                Container(
                  width: Dimens.hairline,
                  height: 40,
                  margin: const EdgeInsets.symmetric(
                    horizontal: Dimens.spaceMd,
                  ),
                  color: context.hairline,
                ),
              Expanded(
                child: j < slice.length ? slice[j] : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
      if (end < children.length) {
        rows.add(
          Divider(
            height: Dimens.spaceXl,
            thickness: Dimens.hairline,
            color: context.hairline,
          ),
        );
      }
    }
    return Column(children: rows);
  }
}
