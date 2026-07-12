import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// A selectable option row (icon + title + optional subtitle + check),
/// highlighted when [selected]. Unifies the boat/group/visibility pickers that
/// were re-implemented in schedule_regatta, start_event_regatta and group_form.
class NavisSelectableCard extends StatelessWidget {
  const NavisSelectableCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Custom leading widget (overrides [icon]).
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lead = leading ??
        (icon != null
            ? Container(
                width: Dimens.minTouchTarget,
                height: Dimens.minTouchTarget,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: selected ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(Dimens.radiusMd),
                ),
                child: Icon(icon, color: AppColors.cyan, size: Dimens.iconMd),
              )
            : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.spaceSm),
      child: NavisCard(
        onTap: onTap,
        borderColor: selected ? AppColors.cyan.withValues(alpha: 0.6) : null,
        padding: const EdgeInsets.all(Dimens.spaceMd),
        child: Row(
          children: [
            if (lead != null) ...[
              lead,
              const SizedBox(width: Dimens.spaceMd),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.txtPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.txtSecondary,
                          ),
                    ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.cyan : context.txtSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
