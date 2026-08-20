import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// A glass pill that reads as selected or not — the app's de-facto segmented
/// control, used in the horizontally-scrolling period rows.
///
/// Material's `SegmentedButton` is not used anywhere in Navis: the rows are
/// data-driven and can hold a dozen years, which a fixed segmented control
/// cannot scroll.
class NavisPeriodChip extends StatelessWidget {
  const NavisPeriodChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Tighter padding for the secondary (month) row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimens.radiusLg),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? context.accent.withValues(alpha: 0.18)
                : context.glassBg,
            borderRadius: BorderRadius.circular(Dimens.radiusLg),
            border: Border.all(
              color: selected
                  ? context.accent.withValues(alpha: 0.55)
                  : context.glassBorderColor,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? context.accent : context.txtSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}
