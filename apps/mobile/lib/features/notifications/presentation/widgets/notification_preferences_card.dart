import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_inline_error.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Settings card with one switch per notification category.
///
/// These are the real thing: they hit `PUT /me/notification-preferences`, and a
/// muted category is neither pushed nor filed in the bell. (The two switches
/// that used to live here only wrote to local preferences that nothing ever
/// read, so turning them off changed nothing.)
class NotificationPreferencesCard extends ConsumerWidget {
  const NotificationPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return NavisCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.spaceLg,
              Dimens.spaceLg,
              Dimens.spaceLg,
              Dimens.spaceSm,
            ),
            child: Text(
              l.notifications.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: context.txtSecondary,
              ),
            ),
          ),
          prefsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(Dimens.spaceLg),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.accent,
                  ),
                ),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(Dimens.spaceLg),
              child: NavisInlineError(
                message: l.somethingWentWrong,
                onRetry: () => ref.invalidate(notificationPreferencesProvider),
              ),
            ),
            data: (prefs) => Column(
              children: [
                for (var i = 0; i < prefs.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: context.glassBorderColor.withValues(alpha: 0.3),
                      indent: Dimens.spaceLg,
                      endIndent: Dimens.spaceLg,
                    ),
                  SwitchListTile(
                    title: Text(_label(l, prefs[i].category)),
                    subtitle: Text(_description(l, prefs[i].category)),
                    value: prefs[i].enabled,
                    activeTrackColor: context.accent.withValues(alpha: 0.5),
                    activeThumbColor: context.accent,
                    onChanged: (value) =>
                        _toggle(context, ref, prefs[i].category, value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    NotificationCategory category,
    bool enabled,
  ) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref
          .read(notificationPreferencesProvider.notifier)
          .toggle(category, enabled);
    } catch (_) {
      if (context.mounted) NavisSnackbar.error(context, l.couldNotSave);
    }
  }

  static String _label(AppLocalizations l, NotificationCategory category) {
    return switch (category) {
      NotificationCategory.reminders => l.notifCategoryReminders,
      NotificationCategory.regattaUpdates => l.notifCategoryRegattas,
      NotificationCategory.groupUpdates => l.notifCategoryGroups,
      NotificationCategory.boatActivity => l.notifCategoryBoatActivity,
      NotificationCategory.eventLive => l.notifCategoryEvents,
    };
  }

  static String _description(
      AppLocalizations l, NotificationCategory category) {
    return switch (category) {
      NotificationCategory.reminders => l.notifCategoryRemindersSubtitle,
      NotificationCategory.regattaUpdates => l.notifCategoryRegattasSubtitle,
      NotificationCategory.groupUpdates => l.notifCategoryGroupsSubtitle,
      NotificationCategory.boatActivity => l.notifCategoryBoatActivitySubtitle,
      NotificationCategory.eventLive => l.notifCategoryEventsSubtitle,
    };
  }
}
