import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_link.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_async_view.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// The notification history behind the bell. Everything the API delivered is
/// here, so a missed push is no longer a lost event.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final feedAsync = ref.watch(notificationFeedProvider);
    final hasUnread = feedAsync.valueOrNull?.any((n) => !n.isRead) ?? false;

    return NavisScaffold(
      title: l.notifications,
      showBack: true,
      actions: [
        if (hasUnread)
          TextButton(
            onPressed: () => _markAllRead(context, ref),
            child: Text(
              l.markAllRead,
              style: const TextStyle(color: AppColors.cyan),
            ),
          ),
      ],
      // A pushed screen never sees the bottom nav, so it uses the plain screen
      // padding instead of the list view's nav-clearance default.
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (scroll) {
          final metrics = scroll.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 200) {
            // Fire-and-forget: the notifier guards against re-entry and shows
            // the appended page through its own state.
            unawaited(ref.read(notificationFeedProvider.notifier).loadMore());
          }
          return false;
        },
        child: NavisAsyncListView<AppNotification>(
          value: feedAsync,
          onRefresh: () =>
              ref.read(notificationFeedProvider.notifier).refresh(),
          emptyIcon: Icons.notifications_none_rounded,
          emptyMessage: l.noNotifications,
          emptyDescription: l.noNotificationsDescription,
          shimmerItemHeight: 84,
          padding: Insets.screen,
          itemBuilder: (context, notification, index) {
            return _NotificationTile(
              notification: notification,
              onTap: () => _open(context, ref, notification),
            );
          },
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref.read(notificationFeedProvider.notifier).markAllRead();
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.somethingWentWrong);
    }
  }

  /// Marks the notification read and follows its deep link when it has one.
  /// Reading must not depend on the navigation succeeding, so the mark comes
  /// first and its failure only surfaces as a snackbar.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final l = AppLocalizations.of(context)!;
    final path = notificationPath(notification.linkType, notification.linkId);

    try {
      await ref
          .read(notificationFeedProvider.notifier)
          .markRead(notification.id);
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.somethingWentWrong);
    }

    if (path != null && context.mounted) unawaited(context.push(path));
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final unread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.spaceSm),
      child: NavisCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Dimens.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        AppColors.cyan.withValues(alpha: unread ? 0.18 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(notification.category),
                    size: Dimens.iconSm,
                    color: unread
                        ? AppColors.cyan
                        : AppColors.cyan.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: Dimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          color: context.txtPrimary,
                        ),
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.txtSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: Dimens.spaceXs),
                      Text(
                        _timeLabel(context, l, notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.txtSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread)
                  Semantics(
                    label: l.unreadNotifications(1),
                    child: Container(
                      margin:
                          const EdgeInsets.only(left: Dimens.spaceSm, top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.cyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationCategory? category) {
    return switch (category) {
      NotificationCategory.reminders => Icons.event_available_outlined,
      NotificationCategory.regattaUpdates => Icons.flag_outlined,
      NotificationCategory.groupUpdates => Icons.groups_outlined,
      NotificationCategory.boatActivity => Icons.directions_boat_outlined,
      NotificationCategory.eventLive => Icons.podcasts_outlined,
      null => Icons.notifications_none_rounded,
    };
  }

  /// Localized "how long ago", falling back to a date beyond a week.
  static String _timeLabel(
    BuildContext context,
    AppLocalizations l,
    DateTime when,
  ) {
    final elapsed = DateTime.now().difference(when);
    if (elapsed.inMinutes < 1) return l.timeJustNow;
    if (elapsed.inMinutes < 60) return l.timeMinutesAgo(elapsed.inMinutes);
    if (elapsed.inHours < 24) return l.timeHoursAgo(elapsed.inHours);
    if (elapsed.inDays < 7) return l.timeDaysAgo(elapsed.inDays);
    return NavisDateUtils.formatDateShort(when);
  }
}
