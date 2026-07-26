import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Crew and permissions management, owner-facing.
///
/// Lives on the boat-detail screen next to Maintenance, Bookings and the rest
/// rather than buried in the share sheet: granting a permission is not part of
/// handing out a code, and members who joined later never appeared there.
///
/// [onShare] opens the share flow, offered when there is nobody to manage yet.
Future<void> showBoatMembersSheet(
  BuildContext context, {
  required String boatId,
  VoidCallback? onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.dialogSurface,
    builder: (_) => _BoatMembersSheet(boatId: boatId, onShare: onShare),
  );
}

class _BoatMembersSheet extends ConsumerWidget {
  const _BoatMembersSheet({required this.boatId, this.onShare});

  final String boatId;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final membersAsync = ref.watch(boatMembersProvider(boatId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.boatCrewTitle,
                    style: TextStyle(
                      color: context.txtPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l.retry,
                  onPressed: () => ref.invalidate(boatMembersProvider(boatId)),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceXs),
            Text(
              l.boatCrewExplainer,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
            const SizedBox(height: Dimens.spaceLg),
            Flexible(
              child: SingleChildScrollView(
                child: membersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Dimens.spaceSm),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.somethingWentWrong,
                        style: TextStyle(color: context.txtSecondary),
                      ),
                      const SizedBox(height: Dimens.spaceSm),
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(boatMembersProvider(boatId)),
                        icon: const Icon(Icons.refresh, size: Dimens.iconSm),
                        label: Text(l.retry),
                      ),
                    ],
                  ),
                  data: (members) {
                    if (members.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.notSharedYet,
                            style: TextStyle(color: context.txtSecondary),
                          ),
                          if (onShare != null) ...[
                            const SizedBox(height: Dimens.spaceLg),
                            NavisButton(
                              label: l.shareBoat,
                              icon: Icons.ios_share_rounded,
                              onPressed: () {
                                Navigator.of(context).pop();
                                onShare!();
                              },
                            ),
                          ],
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (final m in members)
                          _MemberPermissionsTile(boatId: boatId, member: m),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shared member with a per-permission toggle editor (owner-facing).
class _MemberPermissionsTile extends ConsumerStatefulWidget {
  const _MemberPermissionsTile({required this.boatId, required this.member});

  final String boatId;
  final BoatMember member;

  @override
  ConsumerState<_MemberPermissionsTile> createState() =>
      _MemberPermissionsTileState();
}

class _MemberPermissionsTileState
    extends ConsumerState<_MemberPermissionsTile> {
  late BoatPermissions _perms = widget.member.permissions;

  Future<void> _update(BoatPermissions next) async {
    final previous = _perms;
    setState(() => _perms = next);
    try {
      await ref
          .read(boatShareRepositoryProvider)
          .setMemberPermissions(widget.boatId, widget.member.userId, next);
    } catch (_) {
      // Revert so the switch never shows a permission the server rejected.
      if (mounted) {
        setState(() => _perms = previous);
        NavisSnackbar.error(
            context, AppLocalizations.of(context)!.somethingWentWrong);
      }
      return;
    }
    ref.invalidate(boatMembersProvider(widget.boatId));
  }

  Future<void> _remove() async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref
          .read(boatShareRepositoryProvider)
          .removeMember(widget.boatId, widget.member.userId);
    } catch (_) {
      if (mounted) NavisSnackbar.error(context, l.somethingWentWrong);
      return;
    }
    ref.invalidate(boatMembersProvider(widget.boatId));
  }

  Widget _toggle(
      String label, bool value, BoatPermissions Function(bool) apply) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      activeThumbColor: AppColors.cyan,
      title: Text(label,
          style: TextStyle(color: context.txtPrimary, fontSize: 13)),
      value: value,
      onChanged: (v) => _update(apply(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding:
            const EdgeInsets.only(left: Dimens.spaceSm, bottom: Dimens.spaceSm),
        leading: const Icon(Icons.person_outline),
        title: Text(widget.member.name,
            style: TextStyle(color: context.txtPrimary)),
        subtitle: Text(l.permissionsCount(_perms.grantedCount),
            style: TextStyle(color: context.txtSecondary, fontSize: 12)),
        children: [
          _toggle(l.permRecordTrips, _perms.canRecordTrips,
              (v) => _perms.copyWith(canRecordTrips: v)),
          _toggle(l.permManageExpenses, _perms.canManageExpenses,
              (v) => _perms.copyWith(canManageExpenses: v)),
          _toggle(l.permManageMaintenance, _perms.canManageMaintenance,
              (v) => _perms.copyWith(canManageMaintenance: v)),
          _toggle(l.permViewDocuments, _perms.canViewDocuments,
              (v) => _perms.copyWith(canViewDocuments: v)),
          _toggle(l.permManageDocuments, _perms.canManageDocuments,
              (v) => _perms.copyWith(canManageDocuments: v)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _remove,
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppColors.red, size: Dimens.iconSm),
              label: Text(l.removeAccess,
                  style: const TextStyle(color: AppColors.red)),
            ),
          ),
        ],
      ),
    );
  }
}
