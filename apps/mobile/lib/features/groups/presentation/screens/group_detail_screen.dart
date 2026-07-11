import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/domain/entities/group_member.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/regattas/domain/entities/regatta.dart';
import 'package:navis_mobile/features/regattas/presentation/providers/regatta_provider.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  String get _currentUserId => supabaseClient.auth.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final groupAsync = ref.watch(groupProvider(groupId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(
        title: groupAsync.valueOrNull?.name ?? l.groupLabel,
        showBack: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: groupAsync.when(
            loading: () => const NavisLoading(),
            error: (e, _) => NavisErrorWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(groupProvider(groupId)),
            ),
            data: (group) => RefreshIndicator(
              color: AppColors.cyan,
              backgroundColor: context.dialogSurface,
              onRefresh: () async {
                ref.invalidate(groupProvider(groupId));
                ref.invalidate(groupMembersProvider(groupId));
                ref.invalidate(groupRequestsProvider(groupId));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _header(context, group),
                  if (group.isOwner &&
                      !group.isPublic &&
                      group.inviteCode != null)
                    _inviteCode(context, group.inviteCode!),
                  if (group.isOwner) _RequestsSection(groupId: groupId),
                  if (group.isActiveMember) ...[
                    Row(
                      children: [
                        Expanded(child: _SectionTitle(l.regattasAndOutings)),
                        TextButton.icon(
                          icon: const Icon(Icons.add,
                              color: AppColors.cyan, size: 18),
                          label: Text(l.scheduleAction,
                              style: const TextStyle(color: AppColors.cyan)),
                          onPressed: () =>
                              context.push('/groups/$groupId/schedule'),
                        ),
                      ],
                    ),
                    _RegattasSection(groupId: groupId),
                  ],
                  const SizedBox(height: 8),
                  _SectionTitle(l.membersLabel),
                  _MembersSection(
                    groupId: groupId,
                    isOwner: group.isOwner,
                    currentUserId: _currentUserId,
                  ),
                  const SizedBox(height: 24),
                  _actions(context, ref, group),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Group group) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.cyanGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.isPublic ? l.publicLabel : l.privateLabel} · ${l.membersCount(group.memberCount)}',
                  style: TextStyle(color: context.txtSecondary, fontSize: 13),
                ),
                if (group.description != null &&
                    group.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    group.description!,
                    style: TextStyle(color: context.txtSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteCode(BuildContext context, String code) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.vpn_key, color: AppColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.inviteCode,
                    style:
                        TextStyle(color: context.txtSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, color: context.txtSecondary),
            tooltip: l.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              NavisSnackbar.info(context, l.codeCopied);
            },
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, Group group) {
    final l = AppLocalizations.of(context)!;
    if (group.isOwner) {
      return TextButton.icon(
        icon: const Icon(Icons.delete_outline, color: AppColors.red),
        label:
            Text(l.deleteGroup, style: const TextStyle(color: AppColors.red)),
        onPressed: () => _confirmDelete(context, ref),
      );
    }
    if (group.isActiveMember) {
      return TextButton.icon(
        icon: const Icon(Icons.logout, color: AppColors.amber),
        label:
            Text(l.leaveGroup, style: const TextStyle(color: AppColors.amber)),
        onPressed: () => _leave(context, ref),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final ok = await _confirm(context, l.deleteGroup, l.deleteGroupConfirm);
    if (!ok) return;
    try {
      await ref.read(groupRepositoryProvider).deleteGroup(groupId);
      ref.invalidate(myGroupsProvider);
      if (!context.mounted) return;
      NavisSnackbar.success(context, l.groupDeleted);
      context.pop();
    } catch (_) {
      if (!context.mounted) return;
      NavisSnackbar.error(context, l.couldNotDelete);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final ok = await _confirm(context, l.leaveGroup, l.leaveGroupConfirm);
    if (!ok) return;
    try {
      await ref.read(groupRepositoryProvider).leaveGroup(groupId);
      ref.invalidate(myGroupsProvider);
      if (!context.mounted) return;
      NavisSnackbar.success(context, l.leftGroup);
      context.pop();
    } catch (_) {
      if (!context.mounted) return;
      NavisSnackbar.error(context, l.couldNotLeave);
    }
  }

  Future<bool> _confirm(
      BuildContext context, String title, String message) async {
    final l = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.dialogSurface,
            title: Text(title, style: TextStyle(color: context.txtPrimary)),
            content:
                Text(message, style: TextStyle(color: context.txtSecondary)),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: Text(l.cancel),
              ),
              TextButton(
                onPressed: () => context.pop(true),
                child: Text(l.confirm,
                    style: const TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.txtPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RequestsSection extends ConsumerWidget {
  const _RequestsSection({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupRequestsProvider(groupId));
    return async.maybeWhen(
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
                AppLocalizations.of(context)!.requestsCount(requests.length)),
            ...requests.map((m) => _requestTile(context, ref, m)),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _requestTile(BuildContext context, WidgetRef ref, GroupMember m) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.person_add_alt, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.userLabel(m.userId.substring(0, 8)),
              style: TextStyle(color: context.txtPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.green),
            tooltip: l.admit,
            onPressed: () => _act(context, ref, m, approve: true),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: AppColors.red),
            tooltip: l.rejectAction,
            onPressed: () => _act(context, ref, m, approve: false),
          ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, GroupMember m,
      {required bool approve}) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(groupRepositoryProvider);
    try {
      if (approve) {
        await repo.approveRequest(groupId, m.userId);
      } else {
        await repo.rejectRequest(groupId, m.userId);
      }
      ref.invalidate(groupRequestsProvider(groupId));
      ref.invalidate(groupMembersProvider(groupId));
      ref.invalidate(groupProvider(groupId));
      if (!context.mounted) return;
      NavisSnackbar.success(
          context, approve ? l.requestAdmitted : l.requestRejected);
    } catch (_) {
      if (!context.mounted) return;
      NavisSnackbar.error(context, l.couldNotProcess);
    }
  }
}

class _RegattasSection extends ConsumerWidget {
  const _RegattasSection({required this.groupId});
  final String groupId;

  static String _statusLabel(AppLocalizations l, String status) =>
      switch (status) {
        'planned' => l.statusScheduled,
        'recording' => l.statusInProgress,
        'completed' => l.statusCompleted,
        'cancelled' => l.statusCancelled,
        _ => status,
      };
  static const _statusColors = {
    'planned': AppColors.cyan,
    'recording': AppColors.green,
    'completed': AppColors.textSecondary,
    'cancelled': AppColors.red,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupRegattasProvider(groupId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      ),
      error: (e, _) => NavisErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(groupRegattasProvider(groupId)),
      ),
      data: (regattas) {
        if (regattas.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(AppLocalizations.of(context)!.noScheduledRegattas,
                style: TextStyle(color: context.txtSecondary)),
          );
        }
        return Column(
          children: regattas.map((r) => _tile(context, r)).toList(),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Regatta r) {
    final color = _statusColors[r.status] ?? context.txtSecondary;
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => context.push('/regattas/${r.id}'),
      child: Row(
        children: [
          Icon(
            r.kind == 'regatta' ? Icons.emoji_events_outlined : Icons.sailing,
            color: AppColors.cyan,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w600)),
                if (r.scheduledAt != null)
                  Text(
                    NavisDateUtils.formatDate(r.scheduledAt!),
                    style: TextStyle(color: context.txtSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _statusLabel(AppLocalizations.of(context)!, r.status),
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection({
    required this.groupId,
    required this.isOwner,
    required this.currentUserId,
  });

  final String groupId;
  final bool isOwner;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupMembersProvider(groupId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      ),
      error: (e, _) => NavisErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(groupMembersProvider(groupId)),
      ),
      data: (members) => Column(
        children: members.map((m) => _memberTile(context, ref, m)).toList(),
      ),
    );
  }

  Widget _memberTile(BuildContext context, WidgetRef ref, GroupMember m) {
    final l = AppLocalizations.of(context)!;
    final isMe = m.userId == currentUserId;
    final label = m.isOwner ? l.roleOwner : l.memberLabel;
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            m.isOwner ? Icons.star : Icons.person,
            color: m.isOwner ? AppColors.amber : context.txtSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${isMe ? l.youLabel : l.userLabel(m.userId.substring(0, 8))} · $label',
              style: TextStyle(color: context.txtPrimary),
            ),
          ),
          if (isOwner && !m.isOwner)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppColors.red, size: 20),
              tooltip: l.expelMember,
              onPressed: () async {
                try {
                  await ref
                      .read(groupRepositoryProvider)
                      .removeMember(groupId, m.userId);
                  ref.invalidate(groupMembersProvider(groupId));
                  ref.invalidate(groupProvider(groupId));
                  if (!context.mounted) return;
                  NavisSnackbar.success(context, l.memberExpelled);
                } catch (_) {
                  if (!context.mounted) return;
                  NavisSnackbar.error(context, l.couldNotExpel);
                }
              },
            ),
        ],
      ),
    );
  }
}
