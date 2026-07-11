import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';

/// A single destructive action, visually separated in a red-accented card and
/// always guarded by a confirm dialog. Standardizes delete/leave actions that
/// were an undifferentiated red tile in some screens and an instant,
/// unconfirmed action in others.
class NavisDangerAction extends StatelessWidget {
  const NavisDangerAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onConfirmed,
    required this.confirmTitle,
    required this.confirmMessage,
    this.subtitle,
    this.confirmLabel,
  });

  final String label;
  final String? subtitle;
  final IconData icon;

  /// Called only after the user confirms.
  final VoidCallback onConfirmed;
  final String confirmTitle;
  final String confirmMessage;
  final String? confirmLabel;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      onTap: () async {
        final ok = await NavisConfirmDialog.show(
          context,
          title: confirmTitle,
          message: confirmMessage,
          confirmLabel: confirmLabel ?? label,
          destructive: true,
        );
        if (ok) onConfirmed();
      },
      borderColor: AppColors.red.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(Dimens.spaceLg),
      child: Row(
        children: [
          Icon(icon, color: AppColors.red, size: Dimens.iconMd),
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.red,
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
        ],
      ),
    );
  }
}
