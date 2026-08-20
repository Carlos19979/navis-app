import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
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
}) async {
  // The crew is fetched BEFORE the sheet slides in. Opening first meant the
  // request landed mid-animation and the sheet swapped its skeleton for the
  // "share this boat" CTA halfway up — the flick this fixes.
  //
  // The subscription is held until the sheet closes because the provider is
  // autoDispose: a bare read would be collected before the sheet could watch
  // it and the whole thing would be fetched twice. Holding it also means the
  // cache from the last visit is still there, so the refresh this provider
  // exists for (a member joins on someone else's device) is asked for
  // explicitly rather than left to disposal timing.
  final container = ProviderScope.containerOf(context, listen: false);
  container.invalidate(boatMembersProvider(boatId));
  final warm = container.listen<AsyncValue<List<BoatMember>>>(
    boatMembersProvider(boatId),
    (_, __) {},
  );
  try {
    await Future.any<void>([
      // Errors are not swallowed, just not awaited here: the sheet reads the
      // same provider and renders its error branch with a retry.
      container
          .read(boatMembersProvider(boatId).future)
          .then<void>((_) {}, onError: (_, __) {}),
      Future<void>.delayed(_crewWarmup),
    ]);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.dialogSurface,
      builder: (_) => _BoatMembersSheet(boatId: boatId, onShare: onShare),
    );
  } finally {
    warm.close();
  }
}

/// How long the crew request gets before the sheet opens anyway. Short enough
/// that the tap still feels immediate (the tile's ripple covers it), long
/// enough that a warm API answers inside it and the sheet opens settled.
const _crewWarmup = Duration(milliseconds: 300);

class _BoatMembersSheet extends ConsumerWidget {
  const _BoatMembersSheet({required this.boatId, this.onShare});

  /// Floor for the content area, applied to every branch so the sheet keeps
  /// one height whether it shows a skeleton, an error, the share CTA or the
  /// crew. A minimum rather than a fixed height: nothing gets squeezed.
  static const _contentMinHeight = 128.0;

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
                // One floor for every branch — skeleton, error, empty CTA and
                // crew alike — so the sheet keeps its height whatever arrives.
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: _contentMinHeight),
                  child: membersAsync.when(
                    loading: () => const NavisShimmer(
                      itemCount: 2,
                      padding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    error: (e, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: Dimens.spaceSm),
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
      activeThumbColor: context.accent,
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
              icon: Icon(Icons.remove_circle_outline,
                  color: context.critical, size: Dimens.iconSm),
              label: Text(l.removeAccess,
                  style: TextStyle(color: context.critical)),
            ),
          ),
        ],
      ),
    );
  }
}
