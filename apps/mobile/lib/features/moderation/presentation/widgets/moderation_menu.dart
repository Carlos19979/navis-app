import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/moderation/presentation/providers/moderation_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Overflow menu offering "Report" and (when [ownerUserId] is set and is not the
/// current user) "Block user" — the user-facing half of App Store guideline 1.2.
///
/// Drop into a screen's app bar `actions:`. [contentType] is 'group' or 'event'.
class ModerationMenuButton extends ConsumerWidget {
  const ModerationMenuButton({
    super.key,
    required this.contentType,
    required this.contentId,
    this.ownerUserId,
    this.onBlocked,
  });

  final String contentType;
  final String contentId;

  /// Owner/creator user id. When null, only "Report" is shown (e.g. events,
  /// which have no owner id, or your own content).
  final String? ownerUserId;

  /// Called after the owner is successfully blocked (e.g. to pop the screen).
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'report':
            _showReportSheet(context, ref);
          case 'block':
            _confirmBlock(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'report',
          child: Row(children: [
            const Icon(Icons.flag_outlined, size: 20),
            const SizedBox(width: 12),
            Text(l.moderationReport),
          ]),
        ),
        if (ownerUserId != null)
          PopupMenuItem(
            value: 'block',
            child: Row(children: [
              const Icon(Icons.block, size: 20),
              const SizedBox(width: 12),
              Text(l.moderationBlock),
            ]),
          ),
      ],
    );
  }

  Future<void> _showReportSheet(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final reasons = <(String, String)>[
      ('spam', l.moderationReasonSpam),
      ('offensive', l.moderationReasonOffensive),
      ('harassment', l.moderationReasonHarassment),
      ('other', l.moderationReasonOther),
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                l.moderationReportTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (value, label) in reasons)
              ListTile(
                title: Text(label),
                onTap: () => Navigator.of(context).pop(value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (reason == null || !context.mounted) return;

    try {
      await ref.read(moderationRepositoryProvider).report(
            contentType: contentType,
            contentId: contentId,
            reason: reason,
          );
      if (context.mounted) {
        NavisSnackbar.success(context, l.moderationReportDone);
      }
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.moderationFailed);
    }
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final userId = ownerUserId;
    if (userId == null) return;

    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.moderationBlockTitle,
      message: l.moderationBlockMessage,
      confirmLabel: l.moderationBlock,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(moderationRepositoryProvider).block(userId);
      // Refresh the blocked list and re-fetch discovery (server hides blocked).
      ref.invalidate(blockedUserIdsProvider);
      ref.invalidate(discoverGroupsProvider);
      if (context.mounted) {
        NavisSnackbar.success(context, l.moderationBlockDone);
      }
      onBlocked?.call();
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.moderationFailed);
    }
  }
}
