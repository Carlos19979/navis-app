import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// One figure with its icon and label — the tile the statistics screens are
/// built from.
///
/// Was duplicated as `_StatCard` (logbook statistics) and `_Kpi` (cost
/// intelligence), which had drifted apart: one scaled with the type scale and
/// had an icon, the other hard-coded `fontSize: 22` and had none.
class NavisStatTile extends StatelessWidget {
  const NavisStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.semanticValue,
  });

  final IconData icon;

  /// The figure, already formatted — `'—'` when there is nothing to show.
  final String value;
  final String label;
  final Color color;

  /// Spoken instead of [value] when the compact form would not read well
  /// ("9 €/MN" for "€/MN 9"). Defaults to `label: value`.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticValue ?? '$label: $value',
      excludeSemantics: true,
      child: NavisCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: Dimens.spaceSm),
            // Scale the value down to fit the card at large text sizes instead
            // of overriding the type scale with a fixed fontSize.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.txtSecondary,
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays [children] out three to a row, padding the last row so the tiles keep
/// their width instead of stretching.
class NavisStatGrid extends StatelessWidget {
  const NavisStatGrid({super.key, required this.children, this.columns = 3});

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
      rows.add(Row(
        children: [
          for (var j = 0; j < columns; j++) ...[
            if (j > 0) const SizedBox(width: 10),
            Expanded(
              child: j < slice.length ? slice[j] : const SizedBox.shrink(),
            ),
          ],
        ],
      ));
      if (end < children.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(children: rows);
  }
}
