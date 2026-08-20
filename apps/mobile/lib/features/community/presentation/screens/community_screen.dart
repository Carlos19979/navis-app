import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/community/presentation/providers/group_search_provider.dart';
import 'package:navis_mobile/features/events/presentation/screens/events_screen.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/groups/presentation/widgets/group_card.dart';
import 'package:navis_mobile/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/join_by_code_sheet.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_plan_badge.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

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
    // Wait for the real plan before gating. Reading the tier synchronously
    // reports free while /me is in flight or after it failed, which showed a
    // paywall to users who already had Pro.
    final tier = await resolveTier(ref);
    if (!mounted) return;
    if (tier == null) {
      // Plan unknown (offline / request failed): say so and let them retry,
      // rather than implying they need to buy something they may already own.
      NavisSnackbar.error(context, l.planCheckFailed);
      ref.invalidate(accountProvider);
      return;
    }
    if (!tier.canCreateGroups) {
      final purchased =
          await showPaywall(context, ref, reason: l.paywallReasonGroups);
      if (!purchased || !mounted) return;
    }
    if (!mounted) return;
    unawaited(context.push('/groups/new'));
  }

  Future<void> _joinByCode() async {
    final l = AppLocalizations.of(context)!;
    final code = await showJoinByCodeSheet(
      context,
      title: l.joinClubTitle,
      description: l.joinByCodeDescription,
      hint: l.inviteCode,
    );
    if (code == null || code.isEmpty) return;
    try {
      final group =
          await ref.read(groupMembershipActionsProvider).joinByCode(code);
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
      appBarBottom: TabBar(
        controller: _tabs,
        labelColor: context.accent,
        unselectedLabelColor: context.txtSecondary,
        indicatorColor: context.accent,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        tabs: [
          Tab(text: l.communityRegattas),
          Tab(text: l.myGroupsTab),
          Tab(text: l.discoverTab),
        ],
      ),
      actions: [
        const NotificationBell(),
        if (_onClubsTab)
          Padding(
            padding: const EdgeInsets.only(right: Dimens.spaceSm),
            child: TextButton.icon(
              onPressed: _joinByCode,
              icon: Icon(
                Icons.vpn_key_outlined,
                size: Dimens.iconSm,
                color: context.accent,
              ),
              label: Text(
                l.joinByCode,
                style: TextStyle(color: context.accent),
              ),
            ),
          ),
      ],
      // Creating a club is Pro. Marked before the tap, like the paid rows on
      // the boat screen, instead of only finding out via the paywall.
      floatingActionButton: _onClubsTab
          ? NavisPlanBadged(
              label: l.proBadge,
              show: !ref.watch(effectiveTierProvider).canCreateGroups,
              child: NavisGradientFab(
                icon: Icons.add,
                onPressed: _onCreateGroup,
                tooltip: l.createGroup,
              ),
            )
          : null,
      safeAreaBottom: false,
      body: TabBarView(
        controller: _tabs,
        children: [
          const EventsBody(),
          _MyGroupsTab(
            onCreateGroup: _onCreateGroup,
            onJoinByCode: _joinByCode,
            onTap: _openGroup,
          ),
          _DiscoverTab(onTap: _openGroup),
        ],
      ),
    );
  }

  void _openGroup(Group group) {
    unawaited(context.push('/groups/${group.id}'));
  }
}

/// Clubs the user already belongs to.
class _MyGroupsTab extends ConsumerWidget {
  const _MyGroupsTab({
    required this.onCreateGroup,
    required this.onJoinByCode,
    required this.onTap,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onJoinByCode;
  final void Function(Group) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return _GroupList(
      state: ref.watch(myGroupsProvider),
      onRefresh: () => ref.invalidate(myGroupsProvider),
      emptyIcon: Icons.groups_outlined,
      emptyMessage: l.notInAnyGroup,
      emptyActionLabel: l.createGroup,
      onEmptyAction: onCreateGroup,
      emptyJoinLabel: l.joinEmptyCta,
      onEmptyJoin: onJoinByCode,
      onTap: onTap,
    );
  }
}

/// Public clubs to join, browsable as a list and searchable by name.
///
/// Typing runs a server-side search (debounced 300 ms, same as the port
/// picker); an empty field falls back to browsing the discover list, so the tab
/// still works for someone who does not know what they are looking for.
class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab({required this.onTap});

  final void Function(Group) onTap;

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab> {
  static const _debounceDelay = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _debounce;

  /// The trimmed query actually sent to the server, updated on debounce — not
  /// on every keystroke, which would fire a request per letter.
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Rebuild now so the clear button tracks the field, but hold the query
    // until the user stops typing.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      final next = value.trim();
      if (next == _query) return;
      setState(() => _query = next);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spaceLg,
            Dimens.spaceMd,
            Dimens.spaceLg,
            Dimens.spaceSm,
          ),
          child: NavisTextField(
            controller: _controller,
            hint: l.searchGroups,
            prefixIcon: Icons.search,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            suffix: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, color: context.txtSecondary),
                    tooltip: l.clearSearch,
                    onPressed: _clear,
                  ),
          ),
        ),
        Expanded(child: _body(l)),
      ],
    );
  }

  Widget _body(AppLocalizations l) {
    final typed = _controller.text.trim();
    if (typed.isEmpty) {
      return _GroupList(
        state: ref.watch(discoverGroupsProvider),
        onRefresh: () => ref.invalidate(discoverGroupsProvider),
        emptyIcon: Icons.travel_explore_outlined,
        emptyMessage: l.noPublicGroups,
        onTap: widget.onTap,
        trailingBuilder: (g) => _JoinButton(group: g),
      );
    }
    if (typed.length < groupSearchMinChars) {
      return Center(
        child: Text(
          l.groupSearchTypeMore,
          style: TextStyle(color: context.txtSecondary),
        ),
      );
    }
    // Still inside the debounce window: the results on screen belong to the
    // previous query, so show the skeleton rather than stale matches.
    if (typed != _query) return const NavisShimmer(itemCount: 4);
    return _GroupList(
      state: ref.watch(groupSearchProvider(_query)),
      onRefresh: () => ref.invalidate(groupSearchProvider(_query)),
      emptyIcon: Icons.search_off,
      emptyMessage: l.noGroupsFound,
      errorMessage: l.groupSearchError,
      onTap: widget.onTap,
      trailingBuilder: (g) => _JoinButton(group: g),
    );
  }
}

/// Shared body for the three club lists (mine, discover, search results):
/// loading / error / empty / populated plus pull-to-refresh.
///
/// It takes the [state] and a [onRefresh] callback instead of a provider
/// because the search results come from an autoDispose *family* element, which
/// is not the same type as the two plain list providers.
class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.state,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onTap,
    this.errorMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.emptyJoinLabel,
    this.onEmptyJoin,
    this.trailingBuilder,
  });

  final AsyncValue<List<Group>> state;
  final VoidCallback onRefresh;
  final IconData emptyIcon;
  final String emptyMessage;
  final void Function(Group) onTap;

  /// Friendly error copy. Without it the raw exception is shown, which is what
  /// the two list providers already did.
  final String? errorMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Optional secondary "join by code" CTA rendered under the empty state, for
  /// members who were invited rather than creating their own club.
  final String? emptyJoinLabel;
  final VoidCallback? onEmptyJoin;
  final Widget Function(Group)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const NavisShimmer(itemCount: 4),
      error: (e, _) => NavisErrorWidget(
        message: errorMessage ?? e.toString(),
        onRetry: onRefresh,
      ),
      data: (groups) {
        if (groups.isEmpty) {
          final empty = NavisEmptyState(
            icon: emptyIcon,
            message: emptyMessage,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction,
          );
          if (emptyJoinLabel == null || onEmptyJoin == null) return empty;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: empty),
              Padding(
                padding: const EdgeInsets.only(bottom: Dimens.navClearance),
                child: TextButton.icon(
                  onPressed: onEmptyJoin,
                  icon: Icon(
                    Icons.vpn_key_outlined,
                    size: Dimens.iconSm,
                    color: context.accent,
                  ),
                  label: Text(
                    emptyJoinLabel!,
                    style: TextStyle(color: context.accent),
                  ),
                ),
              ),
            ],
          );
        }
        return RefreshIndicator(
          color: context.accent,
          backgroundColor: context.dialogSurface,
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              Dimens.navClearance,
            ),
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
        style: TextStyle(color: context.caution, fontSize: 13),
      );
    }
    return TextButton(
      onPressed: () async {
        try {
          await ref.read(groupMembershipActionsProvider).requestJoin(group.id);
          if (!context.mounted) return;
          NavisSnackbar.success(context, l.requestSent);
        } catch (_) {
          if (!context.mounted) return;
          NavisSnackbar.error(context, l.couldNotRequest);
        }
      },
      child: Text(l.requestAction, style: TextStyle(color: context.accent)),
    );
  }
}
