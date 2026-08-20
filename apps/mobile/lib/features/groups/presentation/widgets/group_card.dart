import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// One club, in «my clubs» and in «discover» alike.
///
/// The 48 dp gradient tile with a white icon in it said nothing that the row
/// did not — every row in those lists is a club — and it was the loudest thing
/// on a screen whose job is to be read.
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
    final meta = [
      group.isPublic ? l.publicLabel : l.privateLabel,
      l.membersCountShort(group.memberCount),
      if (group.isOwner && group.pendingCount > 0)
        l.pendingCountShort(group.pendingCount),
    ].join(' · ');

    return Semantics(
      button: onTap != null,
      label: group.name,
      value: meta,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.hairline)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimens.spaceLg),
              child: Row(
                children: [
                  Icon(
                    group.isPublic ? Icons.public_rounded : Icons.lock_outline,
                    size: Dimens.iconLg,
                    color: context.inkMuted,
                  ),
                  const SizedBox(width: Dimens.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NavisType.title3.copyWith(color: context.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          style: NavisType.caption.copyWith(
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      size: Dimens.iconLg,
                      color: context.inkFaint,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
