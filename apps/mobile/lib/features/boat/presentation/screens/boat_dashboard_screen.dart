import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_header.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/readiness/presentation/widgets/readiness_card.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/features/anchor/presentation/providers/anchor_watch_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/shared/widgets/join_by_code_sheet.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class BoatDashboardScreen extends ConsumerStatefulWidget {
  const BoatDashboardScreen({super.key});

  @override
  ConsumerState<BoatDashboardScreen> createState() =>
      _BoatDashboardScreenState();
}

class _BoatDashboardScreenState extends ConsumerState<BoatDashboardScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _offerRecordingRecovery();
      if (mounted) _resumeAnchorWatch();
    });
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
              style: const TextStyle(color: AppColors.red),
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
        final params = [
          if (state.isRegatta && state.trip != null) 'tripId=${state.trip!.id}',
          if (state.isRegatta) 'regatta=true',
        ];
        final query = params.isEmpty ? '' : '?${params.join('&')}';
        unawaited(context.push('/boats/${state.boatId}/record$query'));
      }
    } else {
      // Load the session so discard() can clean up the server-side trip too.
      await notifier.recoverSession();
      await notifier.discard();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(boatsProvider.notifier).loadMore();
    }
  }

  Future<void> _onAddBoat() async {
    final l = AppLocalizations.of(context)!;
    final tier = ref.read(effectiveTierProvider);
    final boats = ref.read(boatsProvider).valueOrNull ?? const [];

    if (boats.length >= tier.maxBoats) {
      if (tier == PlanTier.pro) {
        NavisSnackbar.info(
          context,
          l.planBoatLimitReached,
        );
        return;
      }
      final purchased = await showPaywall(
        context,
        ref,
        reason: l.paywallReasonBoatLimit,
      );
      if (!purchased || !mounted) return;
    }
    if (!mounted) return;
    context.go('/boats/new');
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
    try {
      await ref.read(boatShareRepositoryProvider).joinBoat(code);
      ref.invalidate(sharedBoatsProvider);
      if (mounted) {
        NavisSnackbar.success(context, l.joinedBoat);
      }
    } catch (_) {
      if (mounted) {
        NavisSnackbar.error(context, l.invalidCodeOrJoinError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final boatsAsync = ref.watch(boatsProvider);
    ref.watch(accountProvider); // warm the plan for FAB gating
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: NavisAppBar(
        title: l.myBoats,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Dimens.spaceSm),
            child: TextButton.icon(
              onPressed: _joinBoat,
              icon: const Icon(
                Icons.group_add_outlined,
                size: Dimens.iconSm,
                color: AppColors.cyan,
              ),
              label: Text(
                l.joinBoat,
                style: const TextStyle(color: AppColors.cyan),
              ),
            ),
          ),
        ],
      ),
      body: boatsAsync.when(
        loading: () => const NavisShimmer(itemHeight: 180),
        error: (error, stack) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(boatsProvider),
        ),
        data: (boats) {
          final shared =
              ref.watch(sharedBoatsProvider).valueOrNull ?? const <Boat>[];
          if (boats.isEmpty && shared.isEmpty) {
            return NavisEmptyState(
              icon: Icons.sailing_outlined,
              message: l.noBoats,
              description: l.noBoatsValueProp,
              actionLabel: l.addBoat,
              onAction: _onAddBoat,
            );
          }

          // Single-boat owner: the home IS that boat's overview, not a
          // one-item list to tap through.
          if (boats.length == 1 && shared.isEmpty) {
            return RefreshIndicator(
              color: AppColors.cyan,
              onRefresh: () async {
                ref.invalidate(boatsProvider);
                ref.invalidate(sharedBoatsProvider);
              },
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  Dimens.navClearance,
                ),
                children: [
                  ReadinessCard(boatId: boats.first.id),
                  const SizedBox(height: 12),
                  _BoatCard(boat: boats.first, index: 0),
                ],
              ),
            );
          }

          final hasShared = shared.isNotEmpty;
          final headerCount = hasShared ? 1 : 0;
          final total = boats.length + headerCount + shared.length;

          return RefreshIndicator(
            color: AppColors.cyan,
            onRefresh: () async {
              ref.invalidate(boatsProvider);
              ref.invalidate(sharedBoatsProvider);
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                Dimens.navClearance,
              ),
              itemCount: total,
              itemBuilder: (context, index) {
                if (index < boats.length) {
                  return _BoatCard(boat: boats[index], index: index);
                }
                var i = index - boats.length;
                if (hasShared && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                    child: Text(
                      l.sharedWithMe,
                      style: TextStyle(
                        color: context.txtSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                if (hasShared) i -= 1;
                return _BoatCard(boat: shared[i], index: boats.length + i);
              },
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: Dimens.navClearance),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.cyanGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _onAddBoat,
            tooltip: l.addNewBoat,
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.add,
              color: Colors.white,
              semanticLabel: l.addNewBoat,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoatCard extends ConsumerWidget {
  const _BoatCard({
    required this.boat,
    required this.index,
  });

  final Boat boat;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(boatDocumentSummaryProvider(boat.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NavisCard(
        padding: EdgeInsets.zero,
        // Always tappable, single boat or many: no hunting for a "manage boat"
        // link in the corner.
        onTap: () => context.push('/boats/${boat.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BoatHeader(boat: boat),
            // Info chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.straighten,
                    label: '${boat.lengthMeters} m',
                  ),
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: localizedBoatType(l, boat.type),
                  ),
                  if (boat.homePort != null)
                    _InfoChip(
                      icon: Icons.anchor,
                      label: boat.homePort!,
                    ),
                ],
              ),
            ),
            // Document status badges. Tapping them opens the documents they
            // are warning about, instead of the boat detail.
            if (summaryAsync case AsyncData(:final value))
              if (value.total > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: GestureDetector(
                    onTap: () => context.push('/boats/${boat.id}/documents'),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Worst status first: what needs doing leads, and if
                        // the row wraps it is the "all good" badge that drops
                        // to the second line.
                        if (value.expired > 0)
                          _StatusBadge(
                            count: value.expired,
                            label: l.expired,
                            color: AppColors.red,
                          ),
                        if (value.critical > 0)
                          _StatusBadge(
                            count: value.critical,
                            label: l.critical,
                            color: AppColors.red,
                          ),
                        if (value.warning > 0)
                          _StatusBadge(
                            count: value.warning,
                            label: l.warning,
                            color: AppColors.amber,
                          ),
                        if (value.ok > 0)
                          _StatusBadge(
                            count: value.ok,
                            label: l.valid,
                            color: AppColors.green,
                          ),
                      ],
                    ),
                  ),
                ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _CardAction(
                      label: l.documents,
                      icon: Icons.description_outlined,
                      onTap: () => context.push('/boats/${boat.id}/documents'),
                    ),
                  ),
                  const SizedBox(width: Dimens.spaceSm),
                  Expanded(
                    child: _CardAction(
                      label: l.logbook,
                      icon: Icons.route_outlined,
                      onTap: () => context.push('/boats/${boat.id}/trips'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 50 * index),
        )
        .slideY(
          begin: 0.05,
          end: 0,
          duration: 400.ms,
          delay: Duration(milliseconds: 50 * index),
          curve: Curves.easeOut,
        );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.glassBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.glassBorderColor,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.txtSecondary),
          const SizedBox(width: 4),
          // Flexible + ellipsis: a long home port shortens its own chip
          // instead of overflowing the card.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.txtSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Half-width action inside a boat card, styled like a secondary [NavisButton]
/// but with room for its label: the shared button reserves 24 px of padding on
/// each side, which at half a card's width truncated "Documents" to "Docume…".
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: Dimens.minTouchTarget,
          padding: const EdgeInsets.symmetric(horizontal: Dimens.spaceSm),
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.circular(Dimens.radiusLg),
            border: Border.all(color: context.glassBorderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: Dimens.iconSm, color: AppColors.cyan),
              const SizedBox(width: Dimens.spaceXs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cyan,
                    letterSpacing: 0.2,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
