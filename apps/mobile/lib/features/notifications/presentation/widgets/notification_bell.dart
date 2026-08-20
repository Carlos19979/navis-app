import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// App-bar bell that opens the notification history, with an unread badge.
///
/// The count comes from the server, so it is right even for notifications whose
/// push never arrived (permission denied, push not configured yet).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  /// Badges above this show as "9+" — a two-digit count would not fit the dot.
  static const int _maxBadgeCount = 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    // A failed count must not break the app bar: fall back to no badge.
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Semantics(
      button: true,
      label: unread > 0
          ? '${l.notifications}, ${l.unreadNotifications(unread)}'
          : l.notifications,
      child: Padding(
        padding: const EdgeInsets.only(right: Dimens.spaceXs),
        child: IconButton(
          tooltip: l.notifications,
          onPressed: () => context.push(Routes.notifications),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, size: Dimens.iconMd),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    decoration: BoxDecoration(
                      color: context.critical,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > _maxBadgeCount ? '$_maxBadgeCount+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
