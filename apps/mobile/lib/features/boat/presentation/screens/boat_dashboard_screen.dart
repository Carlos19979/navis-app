import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
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
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
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
    });
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
    final isPro = ref.read(isProProvider);
    final account = ref.read(accountProvider).valueOrNull;
    final boats = ref.read(boatsProvider).valueOrNull ?? const [];
    final maxBoats = isPro ? 3 : (account?.maxBoats ?? 1);

    if (boats.length >= maxBoats) {
      if (isPro) {
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
    final code = await NavisInputDialog.show(
      context,
      title: l.joinBoat,
      hintText: l.inviteCode,
      confirmLabel: l.join,
      uppercase: true,
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
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: l.joinBoat,
            onPressed: _joinBoat,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                children: [
                  ReadinessCard(boatId: boats.first.id),
                  const SizedBox(height: 12),
                  _BoatCard(boat: boats.first, index: 0, focus: true),
                ],
              ),
            );
          }

          final hasShared = shared.isNotEmpty;
          final headerCount = hasShared ? 1 : 0;
          final total = boats.length + headerCount + shared.length + 1;

          return RefreshIndicator(
            color: AppColors.cyan,
            onRefresh: () async {
              ref.invalidate(boatsProvider);
              ref.invalidate(sharedBoatsProvider);
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: total,
              itemBuilder: (context, index) {
                if (index < boats.length) {
                  return _BoatCard(boat: boats[index], index: index);
                }
                var i = index - boats.length;
                if (hasShared) {
                  if (i == 0) {
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
                  i -= 1;
                  if (i < shared.length) {
                    return _BoatCard(boat: shared[i], index: boats.length + i);
                  }
                }
                return const SizedBox(height: 100);
              },
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 112),
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
    this.focus = false,
  });

  final Boat boat;
  final int index;

  /// Single-boat home: render as the boat's overview (adds a Maintenance
  /// quick action + a "manage boat" link, and drops the whole-card tap since
  /// the actions are all inline).
  final bool focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final summaryAsync = ref.watch(boatDocumentSummaryProvider(boat.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NavisCard(
        padding: EdgeInsets.zero,
        onTap: focus ? null : () => context.push('/boats/${boat.id}'),
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
            // Document status badges
            if (summaryAsync case AsyncData(:final value))
              if (value.total > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
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
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: NavisButton(
                      label: l.documents,
                      icon: Icons.description_outlined,
                      variant: NavisButtonVariant.secondary,
                      compact: true,
                      onPressed: () =>
                          context.push('/boats/${boat.id}/documents'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NavisButton(
                      label: l.logbook,
                      icon: Icons.route_outlined,
                      variant: NavisButtonVariant.secondary,
                      compact: true,
                      onPressed: () => context.push('/boats/${boat.id}/trips'),
                    ),
                  ),
                ],
              ),
            ),
            // Single-boat overview: surface Maintenance + a manage link.
            if (focus) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: NavisButton(
                  label: l.maintenanceTab,
                  icon: Icons.build_outlined,
                  variant: NavisButtonVariant.secondary,
                  compact: true,
                  onPressed: () =>
                      context.push('/boats/${boat.id}/maintenance'),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push('/boats/${boat.id}'),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(l.manageBoat),
                ),
              ),
            ],
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.txtSecondary,
                ),
          ),
        ],
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
