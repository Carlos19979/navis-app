import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// A summary card for a group, used in both "my groups" and "discover" lists.
class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.group,
    this.onTap,
    this.trailing,
    super.key,
  });

  final Group group;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.cyanGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      group.isPublic ? Icons.public : Icons.lock_outline,
                      size: 14,
                      color: context.txtSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      group.isPublic ? l.publicLabel : l.privateLabel,
                      style: TextStyle(
                        color: context.txtSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.person_outline,
                        size: 14, color: context.txtSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${group.memberCount}',
                      style: TextStyle(
                        color: context.txtSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (group.isOwner && group.pendingCount > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l.pendingCountShort(group.pendingCount),
                          style: const TextStyle(
                            color: AppColors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Icon(Icons.chevron_right, color: context.txtSecondary),
        ],
      ),
    );
  }
}
