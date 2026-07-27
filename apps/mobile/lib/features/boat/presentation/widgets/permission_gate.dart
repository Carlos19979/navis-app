import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Why the user cannot do something on a shared boat, in their language.
String permissionReason(AppLocalizations l, BoatPermissionArea area) =>
    switch (area) {
      BoatPermissionArea.recordTrips => l.permBlockedRecordTrips,
      BoatPermissionArea.viewDocuments => l.permBlockedViewDocuments,
      BoatPermissionArea.manageDocuments => l.permBlockedManageDocuments,
      BoatPermissionArea.manageMaintenance => l.permBlockedManageMaintenance,
      BoatPermissionArea.manageExpenses => l.permBlockedManageExpenses,
    };

/// A padlock, the reason, and who to ask about it.
///
/// The whole point of this card is to appear **before** the user does the work.
/// The server enforces the same five flags on save, and a 403 at that moment
/// costs the user a recorded trip or a filled-in form.
class BlockedActionCard extends StatelessWidget {
  const BlockedActionCard({
    super.key,
    required this.reason,
    this.onRetry,
    this.compact = false,
  });

  /// The localized explanation, e.g. [permissionReason].
  final String reason;

  /// Shown when the permission could not be *checked* (as opposed to denied):
  /// there is something to try again.
  final VoidCallback? onRetry;

  /// Tighter layout for use inline in a list rather than as a full page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Semantics(
      label: '${l.permBlockedTitle}. $reason',
      child: NavisCard(
        borderColor: AppColors.amber.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: Dimens.iconXl,
                  height: Dimens.iconXl,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amber.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: Dimens.iconSm,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(width: Dimens.spaceMd),
                Expanded(
                  child: Text(
                    l.permBlockedTitle,
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 14 : 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceMd),
            Text(
              reason,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
            if (onRetry == null) ...[
              const SizedBox(height: Dimens.spaceSm),
              Text(
                l.permBlockedAskOwner,
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const SizedBox(height: Dimens.spaceSm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: Dimens.iconSm),
                  label: Text(l.retry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows [child] only while the current user is known to hold [area] on
/// [boatId]; otherwise a [BlockedActionCard] explaining why.
///
/// Fails closed: while the permission set is loading, and if it cannot be
/// fetched at all, the action is not offered. Pass [placeholder] to render
/// something other than nothing during that window (e.g. a disabled button).
class BoatPermissionGate extends ConsumerWidget {
  const BoatPermissionGate({
    super.key,
    required this.boatId,
    required this.area,
    required this.child,
    this.placeholder,
    this.blocked,
    this.compact = false,
  });

  final String boatId;
  final BoatPermissionArea area;

  /// Rendered when the permission is granted.
  final Widget child;

  /// Rendered while the permission set is still loading. Defaults to an empty
  /// box — never to [child].
  final Widget? placeholder;

  /// Replaces the default [BlockedActionCard] when the permission is denied
  /// (e.g. to hide the action entirely somewhere a card would not fit).
  final Widget? blocked;

  /// Passed through to the default [BlockedActionCard].
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final permissions = ref.watch(boatPermissionsProvider(boatId));

    return switch (permissions) {
      AsyncData(:final value) when area.isGrantedIn(value) => child,
      AsyncData() => blocked ??
          BlockedActionCard(
            reason: permissionReason(l, area),
            compact: compact,
          ),
      AsyncError() => BlockedActionCard(
          reason: l.permCheckFailed,
          compact: compact,
          onRetry: () => ref.invalidate(boatPermissionsProvider(boatId)),
        ),
      _ => placeholder ?? const SizedBox.shrink(),
    };
  }
}

/// Imperative counterpart of [BoatPermissionGate], for taps that start a flow
/// (opening a form, beginning a recording) and for the safety net around a
/// mutation the server refused anyway.
///
/// Returns true only when the permission is known to be granted, and otherwise
/// tells the user why with a snackbar. Awaits the lookup rather than reading a
/// possibly-empty cache, so a slow network delays the action instead of
/// silently allowing it.
Future<bool> ensureBoatPermission(
  BuildContext context,
  WidgetRef ref, {
  required String boatId,
  required BoatPermissionArea area,
}) async {
  final l = AppLocalizations.of(context)!;
  BoatPermissions permissions;
  try {
    permissions = await ref.read(boatPermissionsProvider(boatId).future);
  } catch (_) {
    if (context.mounted) NavisSnackbar.error(context, l.permCheckFailed);
    return false;
  }
  if (area.isGrantedIn(permissions)) return true;
  if (context.mounted) {
    NavisSnackbar.error(
      context,
      '${permissionReason(l, area)} ${l.permBlockedAskOwner}',
    );
  }
  return false;
}

/// The localized message for a mutation the server refused on a permission —
/// the safety net that replaces `DioException … FORBIDDEN` on screen.
///
/// Also refreshes [boatPermissionsProvider], since a 403 proves the cached
/// answer was wrong.
void showPermissionDenied(
  BuildContext context,
  WidgetRef ref, {
  required String boatId,
  required BoatPermissionArea area,
}) {
  final l = AppLocalizations.of(context)!;
  ref.invalidate(boatPermissionsProvider(boatId));
  NavisSnackbar.error(
    context,
    '${permissionReason(l, area)} ${l.permBlockedAskOwner}',
  );
}
