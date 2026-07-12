import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/events/presentation/screens/events_screen.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/groups/presentation/widgets/group_card.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Community tab — merges the regattas feed and the clubs (groups) surface,
/// flattened into three top tabs (Regattas · My clubs · Discover) so there is
/// no nested tab bar. Replaces the separate Events and Groups tabs.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _onClubsTab => _tabs.index >= 1;

  Future<void> _onCreateGroup() async {
    final l = AppLocalizations.of(context)!;
    if (!ref.read(isProProvider)) {
      final purchased =
          await showPaywall(context, ref, reason: l.paywallReasonGroups);
      if (!purchased || !mounted) return;
    }
    if (!mounted) return;
    unawaited(context.push('/groups/new'));
  }

  Future<void> _joinByCode() async {
    final l = AppLocalizations.of(context)!;
    final code = await NavisInputDialog.show(
      context,
      title: l.joinByCode,
      hintText: l.inviteCode,
      confirmLabel: l.join,
      uppercase: true,
    );
    if (code == null || code.isEmpty) return;
    try {
      final group = await ref.read(groupRepositoryProvider).joinByCode(code);
      ref.invalidate(myGroupsProvider);
      if (!mounted) return;
      NavisSnackbar.success(context, l.joinedGroup(group.name));
    } catch (_) {
      if (!mounted) return;
      NavisSnackbar.error(context, l.invalidCodeOrJoinError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    ref.watch(accountProvider); // warm the plan for create-group gating

    return NavisScaffold(
      title: l.community,
      showProfileAction: false,
      appBarBottom: TabBar(
        controller: _tabs,
        labelColor: AppColors.cyan,
        unselectedLabelColor: context.txtSecondary,
        indicatorColor: AppColors.cyan,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        tabs: [
          Tab(text: l.communityRegattas),
          Tab(text: l.myGroupsTab),
          Tab(text: l.discoverTab),
        ],
      ),
      actions: _onClubsTab
          ? [
              IconButton(
                icon: Icon(Icons.vpn_key_outlined, color: context.txtSecondary),
                tooltip: l.joinByCode,
                onPressed: _joinByCode,
              ),
            ]
          : null,
      floatingActionButton: _onClubsTab
          ? NavisGradientFab(
              icon: Icons.add,
              onPressed: _onCreateGroup,
              tooltip: l.createGroup,
            )
          : null,
      safeAreaBottom: false,
      body: TabBarView(
        controller: _tabs,
        children: [
          const EventsBody(),
          _GroupList(
            provider: myGroupsProvider,
            emptyIcon: Icons.groups_outlined,
            emptyMessage: l.notInAnyGroup,
            emptyActionLabel: l.createGroup,
            onEmptyAction: _onCreateGroup,
            onTap: (g) => context.push('/groups/${g.id}'),
          ),
          _GroupList(
            provider: discoverGroupsProvider,
            emptyIcon: Icons.travel_explore_outlined,
            emptyMessage: l.noPublicGroups,
            onTap: (g) => context.push('/groups/${g.id}'),
            trailingBuilder: (g) => _JoinButton(group: g),
          ),
        ],
      ),
    );
  }
}

class _GroupList extends ConsumerWidget {
  const _GroupList({
    required this.provider,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onTap,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.trailingBuilder,
  });

  final FutureProvider<List<Group>> provider;
  final IconData emptyIcon;
  final String emptyMessage;
  final void Function(Group) onTap;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final Widget Function(Group)? trailingBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const NavisShimmer(itemCount: 4),
      error: (e, _) => NavisErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return NavisEmptyState(
            icon: emptyIcon,
            message: emptyMessage,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          );
        }
        return RefreshIndicator(
          color: AppColors.cyan,
          backgroundColor: context.dialogSurface,
          onRefresh: () async => ref.invalidate(provider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: groups.length,
            itemBuilder: (context, i) => GroupCard(
              group: groups[i],
              onTap: () => onTap(groups[i]),
              trailing: trailingBuilder?.call(groups[i]),
            ),
          ),
        );
      },
    );
  }
}

class _JoinButton extends ConsumerWidget {
  const _JoinButton({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    if (group.isPending) {
      return Text(
        l.pendingLabel,
        style: const TextStyle(color: AppColors.amber, fontSize: 13),
      );
    }
    return TextButton(
      onPressed: () async {
        try {
          await ref.read(groupRepositoryProvider).requestJoin(group.id);
          ref.invalidate(discoverGroupsProvider);
          if (!context.mounted) return;
          NavisSnackbar.success(context, l.requestSent);
        } catch (_) {
          if (!context.mounted) return;
          NavisSnackbar.error(context, l.couldNotRequest);
        }
      },
      child:
          Text(l.requestAction, style: const TextStyle(color: AppColors.cyan)),
    );
  }
}
