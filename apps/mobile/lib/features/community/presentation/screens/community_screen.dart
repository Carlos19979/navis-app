import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/community/presentation/providers/group_search_provider.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/features/events/presentation/providers/event_provider.dart';
import 'package:navis_mobile/features/events/presentation/widgets/calendar_view.dart';
import 'package:navis_mobile/features/events/presentation/widgets/event_card.dart';
import 'package:navis_mobile/features/groups/domain/entities/group.dart';
import 'package:navis_mobile/features/groups/presentation/providers/group_provider.dart';
import 'package:navis_mobile/features/groups/presentation/widgets/group_card.dart';
import 'package:navis_mobile/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/join_by_code_sheet.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_plan_badge.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_section.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

/// Key on the scrollable, so a test can reach the sections below the fold.
const communityScrollKey = Key('community-scroll');

/// Community: regattas and clubs in **one** feed.
///
/// It used to be three sub-tabs (Regattas · My clubs · Discover), which is
/// three problems. Two of them only showed clubs, so «community» meant
/// different things depending on which tab you had left it on. The search box
/// lived inside Discover, so it could not find a club you were already in — the
/// most likely thing to look for. And the two actions moved: «join by code»
/// appeared only on the club tabs, and the create-club button with it, so the
/// same screen offered different doors depending on a tab index nothing on
/// screen explained.
///
/// One scroll, three labelled sections, one search field at the top that
/// filters *everything*. Nothing here is behind a tab.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  static const _debounceDelay = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _debounce;

  /// The trimmed query actually sent to the server, updated on debounce — not
  /// on every keystroke, which would fire a request per letter.
  String _query = '';

  /// The regatta section can show its dates as a calendar. It is a different
  /// *view* of one section, not a tab: the clubs below it stay where they are.
  bool _calendar = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
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

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

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
    unawaited(context.push(Routes.newGroup));
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

  void _openGroup(Group group) {
    unawaited(context.push(Routes.group(group.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    ref.watch(accountProvider); // warm the plan for create-club gating

    final searching = _controller.text.trim().isNotEmpty;

    return NavisScaffold(
      title: l.community,
      actions: const [NotificationBell()],
      // Creating a club is Pro. Marked before the tap, like the paid rows on
      // Today, instead of only finding out via the paywall — and no longer
      // appearing and disappearing with a tab index.
      floatingActionButton: NavisPlanBadged(
        label: l.proBadge,
        show: !ref.watch(effectiveTierProvider).canCreateGroups,
        child: NavisGradientFab(
          icon: Icons.add,
          onPressed: _onCreateGroup,
          tooltip: l.createGroup,
        ),
      ),
      safeAreaBottom: false,
      body: RefreshIndicator(
        color: context.accent,
        backgroundColor: context.surfaceRaised,
        onRefresh: () async {
          ref.invalidate(eventsProvider);
          ref.invalidate(myGroupsProvider);
          ref.invalidate(discoverGroupsProvider);
        },
        child: ListView(
          key: communityScrollKey,
          padding: Insets.gutterWithNav,
          children: [
            const SizedBox(height: Dimens.spaceMd),
            NavisTextField(
              controller: _controller,
              hint: l.searchCommunity,
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              suffix: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.inkMuted,
                      ),
                      tooltip: l.clearSearch,
                      onPressed: _clearSearch,
                    ),
            ),
            const SizedBox(height: Dimens.spaceXl),
            if (searching) ..._searchResults(l) else ..._feed(l),
          ],
        ),
      ),
    );
  }

  // ── The feed ──────────────────────────────────────────────────────────────

  List<Widget> _feed(AppLocalizations l) {
    return [
      _RegattaSection(
        calendar: _calendar,
        onToggleCalendar: () => setState(() => _calendar = !_calendar),
      ).entrance(),
      const SizedBox(height: Dimens.spaceXl),
      _ClubSection(
        title: l.myGroupsTab,
        state: ref.watch(myGroupsProvider),
        onRetry: () => ref.invalidate(myGroupsProvider),
        emptyMessage: l.notInAnyGroup,
        onTap: _openGroup,
        action: TextButton.icon(
          onPressed: _joinByCode,
          icon: Icon(
            Icons.vpn_key_outlined,
            size: Dimens.iconSm,
            color: context.accent,
          ),
          label: Text(l.joinByCode, style: TextStyle(color: context.accent)),
        ),
      ).entrance(index: 1),
      const SizedBox(height: Dimens.spaceXl),
      _ClubSection(
        title: l.discoverTab,
        state: ref.watch(discoverGroupsProvider),
        onRetry: () => ref.invalidate(discoverGroupsProvider),
        emptyMessage: l.noPublicGroups,
        onTap: _openGroup,
        trailingBuilder: (g) => _JoinButton(group: g),
      ).entrance(index: 2),
    ];
  }

  // ── Searching ─────────────────────────────────────────────────────────────

  List<Widget> _searchResults(AppLocalizations l) {
    final typed = _controller.text.trim();

    // Regattas are already loaded, so they filter locally and instantly —
    // there is no server-side search for them and no need for one.
    final regattas = (ref.watch(eventsProvider).valueOrNull ?? const <Event>[])
        .where((e) => e.eventType == 'regatta')
        .where(
          (e) =>
              e.name.toLowerCase().contains(typed.toLowerCase()) ||
              e.locationName.toLowerCase().contains(typed.toLowerCase()),
        )
        .toList(growable: false);

    return [
      if (regattas.isNotEmpty) ...[
        NavisSectionHeader(label: l.communityRegattas),
        for (final e in regattas) EventCard(event: e),
        const SizedBox(height: Dimens.spaceXl),
      ],
      NavisSectionHeader(label: l.clubsLabel),
      if (typed.length < groupSearchMinChars)
        _Quiet(text: l.groupSearchTypeMore)
      // Still inside the debounce window: what is on screen belongs to the
      // previous query, so a skeleton is more honest than stale matches.
      else if (typed != _query)
        const NavisShimmer()
      else
        _ClubResults(
          state: ref.watch(groupSearchProvider(_query)),
          onRetry: () => ref.invalidate(groupSearchProvider(_query)),
          emptyMessage: l.noGroupsFound,
          errorMessage: l.groupSearchError,
          onTap: _openGroup,
          trailingBuilder: (g) => _JoinButton(group: g),
        ),
      if (regattas.isEmpty && typed.length >= groupSearchMinChars)
        const SizedBox(height: Dimens.spaceXl),
    ];
  }
}

/// Upcoming regattas, as a list or as a month.
class _RegattaSection extends ConsumerWidget {
  const _RegattaSection({
    required this.calendar,
    required this.onToggleCalendar,
  });

  final bool calendar;
  final VoidCallback onToggleCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(eventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavisSectionHeader(
          label: l.communityRegattas,
          trailing: IconButton(
            icon: Icon(
              calendar ? Icons.view_list_rounded : Icons.calendar_month_rounded,
              size: Dimens.iconMd,
              color: context.inkMuted,
            ),
            tooltip: calendar ? l.communityRegattas : l.eventDate,
            onPressed: onToggleCalendar,
          ),
        ),
        switch (state) {
          AsyncLoading() => const NavisShimmer(),
          AsyncError(:final error) => NavisErrorWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(eventsProvider),
            ),
          AsyncValue(:final value) => _regattas(
              context,
              l,
              (value ?? const <Event>[])
                  .where((e) => e.eventType == 'regatta')
                  .toList(growable: false),
            ),
        },
      ],
    );
  }

  Widget _regattas(
    BuildContext context,
    AppLocalizations l,
    List<Event> regattas,
  ) {
    if (regattas.isEmpty) {
      // A regatta is scheduled from a club, so «add one» is not something this
      // section can offer. The clubs are right below, which is the honest way
      // out — and in one feed they are already on screen.
      return _Quiet(text: l.noEventsDescription);
    }
    if (calendar) return CalendarView(events: regattas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final e in regattas) EventCard(event: e)],
    );
  }
}

/// One club list under its heading, with the section's own empty line rather
/// than a full-screen empty state: in a single feed the other sections are
/// still there, so taking over the screen would be a lie.
class _ClubSection extends StatelessWidget {
  const _ClubSection({
    required this.title,
    required this.state,
    required this.onRetry,
    required this.emptyMessage,
    required this.onTap,
    this.action,
    this.trailingBuilder,
  });

  final String title;
  final AsyncValue<List<Group>> state;
  final VoidCallback onRetry;
  final String emptyMessage;
  final void Function(Group) onTap;
  final Widget? action;
  final Widget Function(Group)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NavisSectionHeader(label: title, trailing: action),
        _ClubResults(
          state: state,
          onRetry: onRetry,
          emptyMessage: emptyMessage,
          onTap: onTap,
          trailingBuilder: trailingBuilder,
        ),
      ],
    );
  }
}

class _ClubResults extends StatelessWidget {
  const _ClubResults({
    required this.state,
    required this.onRetry,
    required this.emptyMessage,
    required this.onTap,
    this.errorMessage,
    this.trailingBuilder,
  });

  final AsyncValue<List<Group>> state;
  final VoidCallback onRetry;
  final String emptyMessage;
  final void Function(Group) onTap;

  /// Friendly error copy. Without it the raw exception is shown, which is what
  /// the list providers used to do.
  final String? errorMessage;
  final Widget Function(Group)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AsyncLoading() => const NavisShimmer(),
      AsyncError(:final error) => NavisErrorWidget(
          message: errorMessage ?? error.toString(),
          onRetry: onRetry,
        ),
      AsyncValue(:final value) when (value ?? const []).isEmpty =>
        _Quiet(text: emptyMessage),
      AsyncValue(:final value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in value!)
              GroupCard(
                group: g,
                onTap: () => onTap(g),
                trailing: trailingBuilder?.call(g),
              ),
          ],
        ),
    };
  }
}

/// A section with nothing in it: one muted line, not a full-page empty state.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.spaceMd),
      child: Text(
        text,
        style: NavisType.bodySm.copyWith(color: context.inkMuted),
      ),
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
        style: NavisType.caption.copyWith(color: context.inkMuted),
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
