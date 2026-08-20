import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/deeplinks/join_deep_link.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/theme/tone.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/features/anchor/presentation/providers/anchor_watch_provider.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/boat_actions.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/features/boat/presentation/providers/active_boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_data_sheet.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_hero_header.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_switcher.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/share_boat_sheet.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_members_sheet.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:navis_mobile/features/passport/presentation/passport_export.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/features/readiness/data/readiness_repository.dart';
import 'package:navis_mobile/features/readiness/presentation/providers/readiness_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/readiness_labels.dart';
import 'package:navis_mobile/features/readiness/presentation/readiness_links.dart';
import 'package:navis_mobile/features/readiness/presentation/widgets/readiness_card.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/models/sail_window.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/join_by_code_sheet.dart';
import 'package:navis_mobile/shared/widgets/navis_action_button.dart';
import 'package:navis_mobile/shared/widgets/navis_danger_zone.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_viewer.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/shared/widgets/navis_ring.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Key on the scrollable, so tests and robots can scroll Today without
/// guessing which of the nested scrollables is the page.
const todayScrollKey = Key('today-scroll');

/// The home screen: everything about the boat you are on, in one page.
///
/// Replaces the boat list plus the boat-detail hub. The list was a screen whose
/// only content was a way to reach the next screen, and the hub was twelve rows
/// of navigation — so the two things an owner actually opens the app for, "can I
/// go out?" and "cast off", were four taps away. Here the state, the conditions
/// and both actions are the first screenful, and the sections below are the same
/// destinations without the intermediate stop.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.boatId});

  /// Set when arriving from a deep link (`/boats/:id`) or a notification: that
  /// boat becomes the active one, so the link lands on *its* Today.
  final String? boatId;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _adoptDeepLinkBoat();
      unawaited(_offerRecordingRecovery());
      unawaited(_resumeAnchorWatch());
    });
  }

  /// A `/boats/:id` link is a statement about which boat the user means.
  void _adoptDeepLinkBoat() {
    final id = widget.boatId;
    if (id == null || id.isEmpty) return;
    if (ref.read(activeBoatIdProvider) == id) return;
    ref.read(activeBoatIdProvider.notifier).select(id);
  }

  /// If an anchor watch was armed when the app was killed, silently re-arm it
  /// (it survives in sqlite) and let the user know it's still watching.
  Future<void> _resumeAnchorWatch() async {
    final notifier = ref.read(anchorWatchProvider.notifier);
    if (!await notifier.hasPersistedWatch()) return;
    final restored = await notifier.recoverWatch();
    if (restored && mounted) {
      NavisSnackbar.info(context, AppLocalizations.of(context)!.anchorResumed);
    }
  }

  /// If the app was killed mid-recording, the session survives in sqlite —
  /// offer to resume it (restores points + stats and reopens the map) or
  /// discard it.
  Future<void> _offerRecordingRecovery() async {
    final notifier = ref.read(tripRecordingProvider.notifier);
    if (!await notifier.hasPersistedSession()) return;
    if (!mounted) return;

    final l = AppLocalizations.of(context)!;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.resumeRecordingTitle),
        content: Text(l.resumeRecordingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l.discardRecording,
              style: TextStyle(color: context.critical),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.resumeAction),
          ),
        ],
      ),
    );
    if (!mounted || resume == null) return;

    if (resume) {
      final restored = await notifier.recoverSession();
      final state = ref.read(tripRecordingProvider);
      if (restored && mounted && state.boatId != null) {
        // The screen sees the already-active recording and won't auto-start.
        unawaited(
          context.push(
            Routes.boatRecord(
              state.boatId!,
              tripId: state.isRegatta ? state.trip?.id : null,
              regatta: state.isRegatta,
            ),
          ),
        );
      }
    } else {
      // Load the session so discard() can clean up the server-side trip too.
      await notifier.recoverSession();
      await notifier.discard();
    }
  }

  Future<void> _onAddBoat() async {
    final l = AppLocalizations.of(context)!;
    final tier = ref.read(effectiveTierProvider);
    final boats = ref.read(boatsProvider).valueOrNull ?? const [];

    if (boats.length >= tier.maxBoats) {
      if (tier == PlanTier.pro) {
        NavisSnackbar.info(context, l.planBoatLimitReached);
        return;
      }
      final purchased = await showPaywall(
        context,
        ref,
        reason: l.paywallReasonBoatLimit(tier.maxBoats),
        // Plus is what answers «I want a second boat»; Pro is the next step up
        // and the sheet lists it too. The copy used to promise Pro for a boat
        // Plus already allows.
        requiredTier: PlanTier.plus,
      );
      if (!purchased || !mounted) return;
    }
    if (!mounted) return;
    unawaited(context.push(Routes.newBoat));
  }

  Future<void> _joinBoat() async {
    final l = AppLocalizations.of(context)!;
    final code = await showJoinByCodeSheet(
      context,
      title: l.joinBoat,
      description: l.joinByCodeDescription,
      hint: l.inviteCode,
    );
    if (code == null || code.isEmpty) return;
    await _joinWithCode(code);
  }

  /// Joins the boat behind [code], reporting the outcome either way.
  Future<void> _joinWithCode(String code) async {
    final l = AppLocalizations.of(context)!;
    try {
      await ref.read(boatShareRepositoryProvider).joinBoat(code);
      ref.invalidate(sharedBoatsProvider);
      if (mounted) NavisSnackbar.success(context, l.joinedBoat);
    } catch (_) {
      if (mounted) NavisSnackbar.error(context, l.invalidCodeOrJoinError);
    }
  }

  /// The invite code currently being handled, so a rebuild does not offer the
  /// same one twice.
  String? _handlingInvite;

  /// Handles a pending invite code after the current frame.
  ///
  /// Deferred on purpose: it is picked up during build, and clearing the
  /// provider or pushing a dialog mid-build is not allowed.
  void _scheduleInvite(String code) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_acceptInvite(code));
    });
  }

  /// An invite link opened the app. Confirm before acting: a tap on a link is
  /// not consent to hand your account to whoever sent it, and the boat's name
  /// is not known until the join goes through.
  Future<void> _acceptInvite(String code) async {
    final l = AppLocalizations.of(context)!;
    // Cleared first, so a refused or failed invite is not offered again on the
    // next rebuild.
    ref.read(pendingJoinCodeProvider.notifier).state = null;
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.joinBoat,
      message: l.joinBoatInviteConfirm(code),
      confirmLabel: l.join,
    );
    if (!confirmed || !mounted) {
      _handlingInvite = null;
      return;
    }
    await _joinWithCode(code);
    _handlingInvite = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final boatsAsync = ref.watch(boatsProvider);
    ref.watch(sharedBoatsProvider);
    ref.watch(accountProvider); // warm the plan for the gated rows

    // An invite code from a link the app was opened with. This screen is the
    // first authenticated thing the user sees, which is why it consumes it.
    // Watched, not listened to: the link can land before this screen exists
    // (cold start, or the user was on another tab), and a listener only hears
    // changes that happen while it is mounted.
    final pending = ref.watch(pendingJoinCodeProvider);
    if (pending != null && pending != _handlingInvite) {
      _handlingInvite = pending;
      _scheduleInvite(pending);
    }

    final boat = ref.watch(activeBoatProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: switch ((boatsAsync, boat)) {
            (AsyncLoading(), null) => const NavisShimmer(itemHeight: 140),
            (AsyncError(:final error), null) => NavisErrorWidget(
                message: error.toString(),
                onRetry: () => ref.invalidate(boatsProvider),
              ),
            // Two ways out, not one. Joining used to live in the app bar of
            // the boat list, which meant it was on screen above the empty
            // state; on Today it moved into the "My boats" section, which only
            // exists once you *have* a boat. That left a crew member invited to
            // someone else's boat — no boat of their own to add — with no way
            // to enter the code at all.
            (_, null) => NavisEmptyState(
                icon: Icons.sailing_outlined,
                message: l.noBoats,
                description: l.noBoatsValueProp,
                actionLabel: l.addBoat,
                onAction: _onAddBoat,
                secondaryActionLabel: l.joinBoat,
                onSecondaryAction: _joinBoat,
              ),
            (_, final active?) => _TodayBody(
                boat: active,
                onAddBoat: _onAddBoat,
                onJoinBoat: _joinBoat,
              ),
          },
        ),
      ),
    );
  }
}

class _TodayBody extends ConsumerStatefulWidget {
  const _TodayBody({
    required this.boat,
    required this.onAddBoat,
    required this.onJoinBoat,
  });

  final Boat boat;
  final VoidCallback onAddBoat;
  final VoidCallback onJoinBoat;

  @override
  ConsumerState<_TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends ConsumerState<_TodayBody> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boat = widget.boat;

    // Switching boats rewrites the whole page, so staying where you were means
    // landing at the bottom of a different boat's Today — on the very list you
    // just tapped, which reads as "nothing happened". Central listener rather
    // than a callback per entry point, so the header's picker, the rows below
    // and a deep link all behave the same.
    ref.listen(activeBoatIdProvider, (previous, next) {
      if (previous == next || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
    });

    return RefreshIndicator(
      color: context.accent,
      onRefresh: () async {
        ref.invalidate(boatsProvider);
        ref.invalidate(sharedBoatsProvider);
        ref.invalidate(boatReadinessProvider(boat.id));
        ref.invalidate(boatDocumentSummaryProvider(boat.id));
      },
      child: ListView(
        key: todayScrollKey,
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: Dimens.navClearance),
        children: [
          // The hero carries the score when there is a photo to frost it
          // over; without one the header is typographic and the score gets its
          // own row underneath.
          _Hero(
            boat: boat,
            onAddBoat: widget.onAddBoat,
            onJoinBoat: widget.onJoinBoat,
          ).entrance(),
          _ConditionsBlock(boat: boat).entrance(index: 1),
          _ActionsBlock(boat: boat).entrance(index: 2),
          _ComingUpBlock(boat: boat).entrance(index: 3),
          _SectionsBlock(boat: boat).entrance(index: 4),
          if (!boat.isOwner)
            _CrewPermissionsBlock(boat: boat).entrance(index: 5),
          _DangerBlock(boat: boat).entrance(index: 6),
        ],
      ),
    );
  }
}

/// The opening of the page.
///
/// With a photo: the boat's own image, its name on it, and the readiness score
/// in a frosted disc over the corner — the one blur on this screen that has
/// something behind it. Without one: a typographic header and the score on its
/// own row, which is what every boat had before anyone uploaded a picture.
class _Hero extends ConsumerWidget {
  const _Hero({
    required this.boat,
    required this.onAddBoat,
    required this.onJoinBoat,
  });

  final Boat boat;
  final VoidCallback onAddBoat;
  final VoidCallback onJoinBoat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = _photosOf(boat);
    final readiness = ref.watch(boatReadinessProvider(boat.id)).valueOrNull;
    final arc = readiness == null
        ? context.inkFaint
        : switch (readiness.status) {
            ReadinessStatus.ready => context.positiveFill,
            ReadinessStatus.attention => context.cautionFill,
            ReadinessStatus.notReady => context.criticalFill,
          };
    void openReadiness() => context.push(Routes.boatReadiness(boat.id));

    if (photos.isEmpty) {
      return Column(
        children: [
          _PlainHeader(
            boat: boat,
            onAddBoat: onAddBoat,
            onJoinBoat: onJoinBoat,
          ),
          _StatusRow(
            boat: boat,
            readiness: readiness,
            arc: arc,
            onTap: openReadiness,
          ),
        ],
      );
    }

    return Column(
      children: [
        BoatHeroHeader(
          boat: boat,
          photoUrl: photos.first,
          score: readiness?.score,
          scoreColor: arc,
          onScoreTap: openReadiness,
          onPhotoTap: () => showNavisPhotoViewer(context, urls: photos),
        ),
        // The status still needs its sentence; the disc only carries the
        // number, and "72" alone does not say whether that is good.
        _StatusLine(
          boat: boat,
          readiness: readiness,
          onTap: openReadiness,
        ),
      ],
    );
  }
}

/// The header when there is no photograph: type, and space.
class _PlainHeader extends StatelessWidget {
  const _PlainHeader({
    required this.boat,
    required this.onAddBoat,
    required this.onJoinBoat,
  });

  final Boat boat;
  final VoidCallback onAddBoat;
  final VoidCallback onJoinBoat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spaceLg,
        Dimens.spaceSm,
        Dimens.spaceSm,
        Dimens.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.today.toUpperCase(),
                  style: NavisType.overline.copyWith(color: context.inkMuted),
                ),
                const SizedBox(height: 2),
                BoatSwitcher(
                  boat: boat,
                  onAddBoat: onAddBoat,
                  onJoinBoat: onJoinBoat,
                ),
                Text(
                  [
                    localizedBoatType(l, boat.type),
                    if (boat.homePort != null) boat.homePort!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NavisType.bodySm.copyWith(color: context.inkMuted),
                ),
              ],
            ),
          ),
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            iconSize: Dimens.iconLg,
            color: context.inkMuted,
            tooltip: l.account,
            onPressed: () => context.go(Routes.profile),
          ),
        ],
      ),
    );
  }
}

/// "Can I go out?", answered as a gauge.
/// Score, verdict and count, on the canvas. Used when there is no photograph
/// to put the score over.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.boat,
    required this.readiness,
    required this.arc,
    required this.onTap,
  });

  final Boat boat;

  /// Null while the summary is loading: the row keeps its height so the page
  /// below it does not jump when the score lands.
  final Readiness? readiness;
  final Color arc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final r = readiness;
    if (r == null) {
      return const Padding(
        padding: Insets.gutter,
        child: SizedBox(height: 96),
      );
    }
    final count = r.attention.length;

    return Semantics(
      button: true,
      label: ReadinessCard.statusLabel(l, r.status),
      value: '${r.score}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.spaceLg,
              vertical: Dimens.spaceSm,
            ),
            child: Row(
              children: [
                // The arc is a shape, so it takes the fill-role accent: the
                // text-role amber is darkened to clear AA as a glyph, and that
                // reads as brown on a ring.
                NavisRing(value: r.score, color: arc, caption: '/100'),
                const SizedBox(width: Dimens.spaceXl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ReadinessCard.statusLabel(l, r.status),
                        style: NavisType.title2.copyWith(color: context.ink),
                      ),
                      const SizedBox(height: Dimens.spaceXs),
                      Text(
                        count == 0
                            ? l.readinessAllGood
                            : l.readinessItemsNeedAttention(count),
                        style: NavisType.bodySm.copyWith(
                          color: context.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.inkFaint,
                  size: Dimens.iconLg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The verdict as a single tappable line, for when the score already sits in
/// the photo header. «72» on its own does not say whether that is good.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.boat,
    required this.readiness,
    required this.onTap,
  });

  final Boat boat;
  final Readiness? readiness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final r = readiness;
    if (r == null) return const SizedBox(height: 56);
    final count = r.attention.length;

    // Wrapped in a NavisList, which is what owns the horizontal gutter — a bare
    // NavisRow sat flush against the screen edge, out of line with every other
    // row on the page.
    return NavisList(
      children: [
        NavisRow(
          title: ReadinessCard.statusLabel(l, r.status),
          subtitle: count == 0
              ? l.readinessAllGood
              : l.readinessItemsNeedAttention(count),
          onTap: onTap,
        ),
      ],
    );
  }
}

/// Wind, sea and the sailing verdict — the reason the app was opened, on the
/// screen where the decision is made instead of one tab away.
class _ConditionsBlock extends ConsumerWidget {
  const _ConditionsBlock({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final overview = ref.watch(weatherOverviewProvider).valueOrNull;
    if (overview == null) return const SizedBox.shrink();

    final wind = overview.current.windSpeed;
    final wave = overview.current.waveHeight;
    final window = SailWindow.evaluate(windKnots: wind, waveMetres: wave);
    final (color, label) = switch (window) {
      SailWindow.good => (context.positive, l.sailConditionsGood),
      SailWindow.moderate => (context.caution, l.sailConditionsModerate),
      SailWindow.adverse => (context.critical, l.sailConditionsAdverse),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spaceLg,
        Dimens.spaceMd,
        Dimens.spaceLg,
        Dimens.spaceMd,
      ),
      child: Semantics(
        button: true,
        label: label,
        value: l.windWavesSummary(
          wind.round().toString(),
          Measure.decimal(locale, wave),
        ),
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => context.go(Routes.weather),
            borderRadius: BorderRadius.circular(Dimens.radiusControl),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.wash(color),
                borderRadius: BorderRadius.circular(Dimens.radiusControl),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Dimens.spaceMd),
                child: Row(
                  children: [
                    Icon(Icons.air_rounded, color: color, size: Dimens.iconLg),
                    const SizedBox(width: Dimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: NavisType.title3.copyWith(color: color),
                          ),
                          Text(
                            l.windWavesSummary(
                              wind.round().toString(),
                              Measure.decimal(locale, wave),
                            ),
                            style: NavisType.caption.copyWith(
                              color: context.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.inkFaint,
                      size: Dimens.iconLg,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cast off, and drop the anchor watch. One tap each.
class _ActionsBlock extends ConsumerWidget {
  const _ActionsBlock({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spaceLg,
        Dimens.spaceSm,
        Dimens.spaceLg,
        Dimens.spaceSm,
      ),
      child: NavisActionBar(
        actions: [
          if (BoatActions.canSail(boat))
            NavisActionButton(
              icon: Icons.play_arrow_rounded,
              label: BoatActions.sailLabel(l, ref),
              primary: true,
              onTap: () => BoatActions.sail(context, ref, boat),
            ),
          NavisActionButton(
            icon: Icons.anchor_rounded,
            label: l.anchorActionShort,
            lockLabel: BoatActions.anchorLock(l, ref),
            onTap: () => BoatActions.anchor(context, ref, boat),
          ),
        ],
      ),
    );
  }
}

/// The three nearest things that need doing, with the deep link to fix each.
class _ComingUpBlock extends ConsumerWidget {
  const _ComingUpBlock({required this.boat});

  final Boat boat;

  /// Three is the point: this is a preview that answers "anything urgent?", not
  /// a second copy of the readiness screen.
  static const _maxItems = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final readiness = ref.watch(boatReadinessProvider(boat.id)).valueOrNull;
    if (readiness == null) return const SizedBox.shrink();

    if (readiness.attention.isEmpty) {
      return NavisList(
        title: l.nextUp,
        children: [
          NavisRow(
            title: l.todayNothingDue,
            icon: Icons.check_circle_outline_rounded,
            iconColor: context.positive,
            showChevron: false,
          ),
        ],
      );
    }

    final items = readiness.attention.take(_maxItems).toList();
    final hasMore = readiness.attention.length > _maxItems;

    return NavisList(
      title: l.nextUp,
      action: hasMore
          ? _TextAction(
              label: l.seeAll,
              onTap: () => context.push(Routes.boatReadiness(boat.id)),
            )
          : null,
      children: [
        for (final item in items)
          NavisRow(
            title: readinessItemTitle(l, item),
            value: readinessDaysLabel(l, item),
            valueTone: item.status == ReadinessStatus.notReady
                ? NavisTone.critical
                : NavisTone.caution,
            icon: Icons.circle,
            iconColor: item.status == ReadinessStatus.notReady
                ? context.criticalFill
                : context.cautionFill,
            onTap: switch (readinessRoute(
              boatId: boat.id,
              category: item.category,
              ref: item.ref,
            )) {
              final route? => () => context.push(route),
              _ => null,
            },
          ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, Dimens.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceSm),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        style: NavisType.label.copyWith(color: context.accent),
      ),
    );
  }
}

/// Everything the boat owns, as destinations rather than as a menu.
///
/// This is what the twelve-row hub becomes: the same routes, but reached from
/// the screen the user is already on, with the numbers that make a row worth
/// tapping printed on it.
/// Everything the boat owns, as destinations rather than as a menu.
///
/// One heading, not two. «Barco» and «Gestionar barco» were five headings on a
/// page that already had three, and the split told the user nothing they could
/// not see from the rows themselves — the management rows just come last, with
/// a gap.
class _SectionsBlock extends ConsumerWidget {
  const _SectionsBlock({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tier = ref.watch(effectiveTierProvider);
    final summary = ref.watch(boatDocumentSummaryProvider(boat.id)).valueOrNull;

    return NavisList(
      title: l.boat,
      children: [
        NavisRow(
          title: l.documents,
          icon: Icons.description_outlined,
          value: documentsValue(l, summary),
          valueTone: documentsTone(summary),
          onTap: () => context.push(Routes.boatDocuments(boat.id)),
        ),
        NavisRow(
          title: l.logbook,
          icon: Icons.route_outlined,
          onTap: () => context.push(Routes.boatTrips(boat.id)),
        ),
        NavisRow(
          title: l.tripStatistics,
          icon: Icons.query_stats_rounded,
          onTap: () => context.push(Routes.boatStats(boat.id)),
        ),
        // Two rows, because they are two screens: «maintenance and expenses»
        // named one screen with 26 actions in it, and a row whose title is two
        // nouns joined by «and» is a row that does two things.
        NavisRow(
          title: l.maintenanceTab,
          icon: Icons.build_outlined,
          onTap: () => context.push(Routes.boatMaintenance(boat.id)),
        ),
        NavisRow(
          title: l.expensesTab,
          icon: Icons.receipt_long_outlined,
          onTap: () => context.push(Routes.boatExpenses(boat.id)),
        ),
        // Paid rows are marked before the tap, and quietly: a lock and the tier
        // in muted ink. They used to carry the same filled amber chip as an
        // expired document, so «you have to pay» read as loud as «this lapsed».
        NavisRow(
          title: l.costTitle,
          icon: Icons.insights_rounded,
          lockLabel: tier.canCostAnalytics ? null : l.proBadge,
          onTap: () => _openGated(
            context,
            ref,
            allowed: tier.canCostAnalytics,
            reason: l.paywallReasonCostAnalytics,
            route: Routes.boatCosts(boat.id),
          ),
        ),
        if (boat.isOwner)
          NavisRow(
            title: l.bookingsTitle,
            icon: Icons.calendar_month_outlined,
            lockLabel: tier.canSharedCoordination ? null : l.proBadge,
            onTap: () => _openGated(
              context,
              ref,
              allowed: tier.canSharedCoordination,
              reason: l.paywallReasonShared,
              route: Routes.boatBookings(boat.id),
            ),
          ),
        if (boat.isOwner) ...[
          NavisRow(
            title: l.passportExport,
            icon: Icons.picture_as_pdf_outlined,
            lockLabel: tier.canExportPassport ? null : l.proBadge,
            onTap: () => unawaited(exportBoatPassport(context, ref, boat)),
          ),
          NavisRow(
            title: l.boatCrewTitle,
            icon: Icons.group_outlined,
            onTap: () => unawaited(
              showBoatMembersSheet(context, boatId: boat.id),
            ),
          ),
          NavisRow(
            title: l.shareBoat,
            icon: Icons.ios_share_rounded,
            onTap: () => unawaited(showShareBoatSheet(context, boat)),
          ),
          NavisRow(
            title: l.editBoat,
            icon: Icons.edit_outlined,
            onTap: () => context.push(Routes.boatEdit(boat.id)),
          ),
        ],
        // Registration, type, length, home port and the photo gallery. Four
        // rows nobody reads daily, so they go behind one that says what they
        // are instead of taking a block in the middle of the page.
        NavisRow(
          title: l.boatData,
          icon: Icons.info_outline_rounded,
          onTap: () => unawaited(showBoatDataSheet(context, boat)),
        ),
      ],
    );
  }

  Future<void> _openGated(
    BuildContext context,
    WidgetRef ref, {
    required bool allowed,
    required String reason,
    required String route,
    PlanTier requiredTier = PlanTier.pro,
  }) async {
    if (!allowed) {
      final ok = await showPaywall(
        context,
        ref,
        reason: reason,
        requiredTier: requiredTier,
      );
      if (!ok || !context.mounted) return;
    }
    if (context.mounted) unawaited(context.push(route));
  }
}

/// The boat's photos, if it has any.
///
/// Kept because it is the only way to *look* at them — the gallery is a plan
/// gate (`GalleryLimit`), and retiring the detail hub would otherwise have left
/// a paid feature with no screen.
List<String> _photosOf(Boat boat) => [
      if (boat.photoUrl != null && boat.photoUrl!.isNotEmpty) boat.photoUrl!,
      ...boat.photoUrls,
    ];

/// What a crew member is allowed to do on someone else's boat.
///
/// Shown only to members, and it is the honest version of the old behaviour:
/// permissions fail closed, so without this the member just found buttons
/// missing with no explanation of who to ask.
class _CrewPermissionsBlock extends ConsumerWidget {
  const _CrewPermissionsBlock({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final permissions = ref.watch(boatPermissionsProvider(boat.id));

    return switch (permissions) {
      AsyncData(:final value) => NavisList(
          title: l.myPermissionsTitle,
          children: [
            for (final area in BoatPermissionArea.values)
              NavisRow(
                title: permissionAreaLabel(l, area),
                dense: true,
                showChevron: false,
                trailing: Icon(
                  area.isGrantedIn(value)
                      ? Icons.check_rounded
                      : Icons.lock_outline_rounded,
                  size: Dimens.iconMd,
                  color: area.isGrantedIn(value)
                      ? context.positive
                      : context.inkFaint,
                ),
              ),
            NavisRow(
              title: l.permBlockedAskOwner,
              dense: true,
              showChevron: false,
            ),
          ],
        ),
      AsyncError() => NavisList(
          title: l.myPermissionsTitle,
          children: [
            NavisRow(
              title: l.permCheckFailed,
              dense: true,
              showChevron: false,
              trailing: TextButton(
                onPressed: () =>
                    ref.invalidate(boatPermissionsProvider(boat.id)),
                child: Text(l.retry),
              ),
            ),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Deleting the boat, or walking away from a shared one. Separated from
/// everything else and always confirmed.
class _DangerBlock extends ConsumerWidget {
  const _DangerBlock({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spaceLg,
        Dimens.spaceXxl,
        Dimens.spaceLg,
        Dimens.spaceLg,
      ),
      child: NavisDangerAction(
        icon:
            boat.isOwner ? Icons.delete_outline_rounded : Icons.logout_rounded,
        label: boat.isOwner ? l.deleteBoat : l.leaveSharedBoat,
        subtitle: boat.isOwner ? l.removePermanently : null,
        confirmTitle: boat.isOwner ? l.deleteBoat : l.leaveBoat,
        confirmMessage: boat.isOwner
            ? l.deleteBoatConfirm(boat.name)
            : l.leaveBoatConfirm(boat.name),
        confirmLabel: boat.isOwner ? l.delete : l.leave,
        onConfirmed: () => unawaited(_run(context, ref)),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    try {
      if (boat.isOwner) {
        await ref.read(boatsProvider.notifier).deleteBoat(boat.id);
      } else {
        await ref.read(boatShareRepositoryProvider).leaveBoat(boat.id);
        ref.invalidate(sharedBoatsProvider);
      }
      // Forget the boat that no longer exists, so the resolver falls back to
      // the next one instead of holding a dead id.
      ref.read(activeBoatIdProvider.notifier).select(null);
    } catch (e) {
      if (context.mounted) {
        NavisSnackbar.error(context, '${l.failedToDelete}: $e');
      }
    }
  }
}

/// Short on purpose: this goes in a chip, and "1 cosa requiere atención"
/// wrapped to two lines and turned a status marker into a paragraph.
String? documentsValue(AppLocalizations l, DocumentSummary? summary) {
  if (summary == null || summary.total == 0) return null;
  final overdue = summary.expired + summary.critical;
  if (overdue > 0) return l.alertsCount(overdue);
  if (summary.warning > 0) return l.alertsCount(summary.warning);
  return l.readinessAllGood;
}

/// Only what needs a decision gets a filled chip. "Everything in order" is
/// quiet muted text: three pills down a list and none of them means anything.
NavisTone documentsTone(DocumentSummary? summary) {
  if (summary == null || summary.total == 0) return NavisTone.neutral;
  if (summary.expired + summary.critical > 0) return NavisTone.critical;
  if (summary.warning > 0) return NavisTone.caution;
  return NavisTone.neutral;
}
