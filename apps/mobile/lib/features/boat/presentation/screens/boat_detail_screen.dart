import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/passport/presentation/passport_export.dart';
import 'package:navis_mobile/features/readiness/presentation/widgets/readiness_card.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_members_sheet.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/trip_recording_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_strip.dart';
import 'package:navis_mobile/shared/widgets/navis_photo_viewer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

class BoatDetailScreen extends ConsumerWidget {
  const BoatDetailScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final boatAsync = ref.watch(boatProvider(boatId));

    return boatAsync.when(
      loading: () => const GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: NavisLoading(),
        ),
      ),
      error: (error, stack) => GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: NavisAppBar(title: l.boat, showBack: true),
          body: NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(boatProvider(boatId)),
          ),
        ),
      ),
      data: (boat) => _BoatDetailView(boat: boat),
    );
  }
}

class _BoatDetailView extends ConsumerWidget {
  const _BoatDetailView({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          slivers: [
            _BoatSliverAppBar(boat: boat),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (boat.photoUrls.isNotEmpty) ...[
                    _GalleryStrip(boat: boat)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05, end: 0, duration: 400.ms),
                    const SizedBox(height: 16),
                  ],
                  _InfoSection(boat: boat)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),
                  ReadinessCard(boatId: boat.id),
                  const SizedBox(height: 16),
                  if (boat.isOwner) ...[
                    _ActionTile(
                      icon: Icons.description_outlined,
                      title: l.documents,
                      subtitle: l.certificates,
                      color: AppColors.cyan,
                      onTap: () => context.push('/boats/${boat.id}/documents'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.route_outlined,
                      title: l.logbook,
                      subtitle: l.tripHistory,
                      color: AppColors.green,
                      onTap: () => context.push('/boats/${boat.id}/trips'),
                    ),
                    const SizedBox(height: 10),
                    // Trip statistics used to hang off the logbook's app bar
                    // only. Everything about the boat is reachable from here.
                    _ActionTile(
                      icon: Icons.query_stats_rounded,
                      title: l.tripStatistics,
                      subtitle: l.tripStatisticsSubtitle,
                      color: AppColors.green,
                      onTap: () => context.push('/boats/${boat.id}/stats'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.build_outlined,
                      title: l.maintenanceAndExpenses,
                      subtitle: l.maintenanceAndExpensesSubtitle,
                      color: AppColors.amber,
                      onTap: () =>
                          context.push('/boats/${boat.id}/maintenance'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.insights_rounded,
                      title: l.costTitle,
                      subtitle: l.costAnalyticsSubtitle,
                      color: AppColors.cyan,
                      badge: ref.watch(effectiveTierProvider).canCostAnalytics
                          ? null
                          : l.proBadge,
                      onTap: () => _openCostAnalytics(context, ref, boat),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.calendar_month_outlined,
                      title: l.bookingsTitle,
                      subtitle: l.bookingsSubtitle,
                      color: AppColors.cyan,
                      onTap: () => _openBookings(context, ref, boat),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.anchor_rounded,
                      title: l.anchorAlarmTitle,
                      subtitle: l.anchorWatchSubtitle,
                      color: AppColors.amber,
                      badge: ref.watch(effectiveTierProvider).canAnchorAlarm
                          ? null
                          : l.plusBadge,
                      onTap: () => _openAnchorWatch(context, ref, boat),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.workspace_premium_outlined,
                      title: l.passportExport,
                      subtitle: l.passportTitle,
                      color: AppColors.green,
                      onTap: () => exportBoatPassport(context, ref, boat),
                    ),
                    const SizedBox(height: 10),
                    // Crew management lives here, with the rest of the boat's
                    // sections, and only for the owner: nobody else can grant
                    // a permission.
                    _ActionTile(
                      icon: Icons.groups_outlined,
                      title: l.boatCrewTitle,
                      subtitle: l.boatCrewSubtitle,
                      color: AppColors.green,
                      onTap: () => showBoatMembersSheet(
                        context,
                        boatId: boat.id,
                        onShare: () => _shareBoat(context, ref, boat),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.ios_share_rounded,
                      title: l.shareBoat,
                      subtitle: l.shareBoatSubtitle,
                      color: AppColors.cyan,
                      onTap: () => _shareBoat(context, ref, boat),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      title: l.editBoat,
                      subtitle: l.modifyBoatDetails,
                      color: AppColors.amber,
                      onTap: () => context.push('/boats/${boat.id}/edit'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.delete_outlined,
                      title: l.deleteBoat,
                      subtitle: l.removePermanently,
                      color: AppColors.red,
                      onTap: () => _confirmDelete(context, ref),
                    ),
                  ] else ...[
                    NavisCard(
                      child: Row(
                        children: [
                          const Icon(Icons.visibility_outlined,
                              color: AppColors.cyan),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.sharedBoatInfo,
                              style: TextStyle(color: context.txtSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // What the owner has actually granted, spelled out. A
                    // member had no way of knowing before hitting a 403.
                    _MyPermissionsCard(boatId: boat.id),
                    const SizedBox(height: 10),
                    // Documents are readable only with can_view_documents; the
                    // gate shows the padlock and the reason instead of a tile
                    // that answers 403.
                    BoatPermissionGate(
                      boatId: boat.id,
                      area: BoatPermissionArea.viewDocuments,
                      compact: true,
                      child: _ActionTile(
                        icon: Icons.description_outlined,
                        title: l.documents,
                        subtitle: l.certificates,
                        color: AppColors.cyan,
                        onTap: () =>
                            context.push('/boats/${boat.id}/documents'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.route_outlined,
                      title: l.logbook,
                      subtitle: l.tripHistory,
                      color: AppColors.green,
                      onTap: () => context.push('/boats/${boat.id}/trips'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.query_stats_rounded,
                      title: l.tripStatistics,
                      subtitle: l.tripStatisticsSubtitle,
                      color: AppColors.green,
                      onTap: () => context.push('/boats/${boat.id}/stats'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.build_outlined,
                      title: l.maintenanceAndExpenses,
                      subtitle: l.maintenanceAndExpensesSubtitle,
                      color: AppColors.amber,
                      onTap: () =>
                          context.push('/boats/${boat.id}/maintenance'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      icon: Icons.logout,
                      title: l.leaveSharedBoat,
                      subtitle: l.leaveSharedBoatSubtitle,
                      color: AppColors.red,
                      onTap: () => _leaveBoat(context, ref, boat),
                    ),
                  ],
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookings(
    BuildContext context,
    WidgetRef ref,
    Boat boat,
  ) async {
    final l = AppLocalizations.of(context)!;
    if (!ref.read(effectiveTierProvider).canSharedCoordination) {
      final ok = await showPaywall(context, ref, reason: l.paywallReasonShared);
      if (!ok || !context.mounted) return;
    }
    if (context.mounted) unawaited(context.push('/boats/${boat.id}/bookings'));
  }

  /// Opens the anchor watch (Plus+).
  ///
  /// This used to hang off a chip in the boats list, which was removed because
  /// it only appeared when the user had exactly one boat. That left the anchor
  /// watch with **no** entry point at all, so it lives here now with the rest
  /// of the boat's sections.
  ///
  /// Blocked while a trip is recording: both drive the GPS stream, and running
  /// them together is what the original guard existed to prevent.
  Future<void> _openAnchorWatch(
    BuildContext context,
    WidgetRef ref,
    Boat boat,
  ) async {
    final l = AppLocalizations.of(context)!;
    if (ref.read(tripRecordingProvider).isActive) {
      NavisSnackbar.info(context, l.anchorTripActiveBlock);
      return;
    }
    if (!ref.read(effectiveTierProvider).canAnchorAlarm) {
      final ok = await showPaywall(
        context,
        ref,
        reason: l.paywallReasonAnchor,
        requiredTier: PlanTier.plus,
      );
      if (!ok || !context.mounted) return;
    }
    if (context.mounted) unawaited(context.push('/boats/${boat.id}/anchor'));
  }

  Future<void> _openCostAnalytics(
    BuildContext context,
    WidgetRef ref,
    Boat boat,
  ) async {
    final l = AppLocalizations.of(context)!;
    if (!ref.read(effectiveTierProvider).canCostAnalytics) {
      final ok = await showPaywall(
        context,
        ref,
        reason: l.paywallReasonCostAnalytics,
      );
      if (!ok || !context.mounted) return;
    }
    if (context.mounted) unawaited(context.push('/boats/${boat.id}/costs'));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.deleteBoat,
      message: l.deleteBoatConfirm(boat.name),
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(boatsProvider.notifier).deleteBoat(boat.id);
      if (context.mounted) {
        context.go('/boats');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.failedToDelete}: $e'),
          ),
        );
      }
    }
  }

  Future<void> _shareBoat(
      BuildContext context, WidgetRef ref, Boat boat) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    String code;
    try {
      code = await ref.read(boatShareRepositoryProvider).shareCode(boat.id);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.couldNotGetCode)),
      );
      return;
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.dialogSurface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.shareBoat,
                style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              l.shareBoatExplainer,
              style: TextStyle(color: context.txtSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.4), width: 0.5),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      messenger.showSnackBar(
                        SnackBar(content: Text(l.codeCopied)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l.copy),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.cyan),
                    onPressed: () => _shareCodeNatively(ctx, boat, code),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(l.share),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showBoatMembersSheet(context, boatId: boat.id);
                },
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: Text(l.boatCrewTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands the code to the OS share sheet — WhatsApp, Telegram, Mail, whatever
  /// the sender uses — instead of only copying it to the clipboard.
  ///
  /// `sharePositionOrigin` is required on iPad, where the sheet is a popover
  /// anchored to the button that opened it.
  Future<void> _shareCodeNatively(
    BuildContext context,
    Boat boat,
    String code,
  ) async {
    final l = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      l.shareBoatMessageWithLink(boat.name, code, _joinLink(code)),
      subject: l.shareBoat,
      sharePositionOrigin: box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }

  /// Deep link that opens the app straight on the join flow with the code
  /// pre-filled. The code stays in the message body so it also works by hand.
  String _joinLink(String code) => 'navis://join?code=$code';

  Future<void> _leaveBoat(
      BuildContext context, WidgetRef ref, Boat boat) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.leaveBoat,
      message: l.leaveBoatConfirm(boat.name),
      confirmLabel: l.leave,
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(boatShareRepositoryProvider).leaveBoat(boat.id);
    ref.invalidate(sharedBoatsProvider);
    if (context.mounted) context.go('/boats');
  }
}

class _BoatSliverAppBar extends StatelessWidget {
  const _BoatSliverAppBar({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.deepNavy,
      foregroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.white,
          ),
          tooltip: AppLocalizations.of(context)!.goBack,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/boats');
            }
          },
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          boat.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 12,
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (boat.photoUrl != null && boat.photoUrl!.isNotEmpty)
              Semantics(
                label: AppLocalizations.of(context)!.boatPhoto,
                child: CachedNetworkImage(
                  imageUrl: boat.photoUrl!,
                  memCacheWidth: 1200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.darkCard,
                  ),
                  errorWidget: (context, url, error) => _placeholderImage(),
                ),
              )
            else
              _placeholderImage(),
            // Improved 3-stop gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.teal],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.sailing,
          size: 64,
          color: AppColors.cyan.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

/// Horizontal gallery under the header: cover plus extra photos, each
/// opening the fullscreen swipe viewer.
class _GalleryStrip extends StatelessWidget {
  const _GalleryStrip({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context) {
    final photos = [
      if (boat.photoUrl != null && boat.photoUrl!.isNotEmpty) boat.photoUrl!,
      ...boat.photoUrls,
    ];
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => NavisPhotoThumb(
          url: photos[i],
          size: 72,
          onTap: () => showNavisPhotoViewer(
            context,
            urls: photos,
            initialIndex: i,
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.details,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.tag,
            label: AppLocalizations.of(context)!.registration,
            value: boat.registration,
          ),
          _glassDivider(context),
          _DetailRow(
            icon: Icons.category_outlined,
            label: AppLocalizations.of(context)!.type,
            value: localizedBoatType(AppLocalizations.of(context)!, boat.type),
          ),
          _glassDivider(context),
          _DetailRow(
            icon: Icons.straighten,
            label: AppLocalizations.of(context)!.length,
            value: '${boat.lengthMeters} m',
          ),
          if (boat.homePort != null) ...[
            _glassDivider(context),
            _DetailRow(
              icon: Icons.anchor,
              label: AppLocalizations.of(context)!.homePort,
              value: boat.homePort!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _glassDivider(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: context.glassBorderColor,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.cyan),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.txtSecondary,
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  /// Optional short pill (e.g. "PRO") shown before the chevron.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.txtSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.amber,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: context.txtSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

/// The member's own permission set, spelled out area by area.
///
/// Fails closed while it loads: nothing is claimed as granted until the server
/// says so.
class _MyPermissionsCard extends ConsumerWidget {
  const _MyPermissionsCard({required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final permissions = ref.watch(boatPermissionsProvider(boatId));

    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.myPermissionsTitle,
            style: TextStyle(
              color: context.txtPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          switch (permissions) {
            AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final area in BoatPermissionArea.values)
                    _PermissionRow(
                      label: _areaLabel(l, area),
                      granted: area.isGrantedIn(value),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    l.permBlockedAskOwner,
                    style: TextStyle(color: context.txtSecondary, fontSize: 12),
                  ),
                ],
              ),
            AsyncError() => Row(
                children: [
                  Expanded(
                    child: Text(
                      l.permCheckFailed,
                      style:
                          TextStyle(color: context.txtSecondary, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(boatPermissionsProvider(boatId)),
                    child: Text(l.retry),
                  ),
                ],
              ),
            _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              ),
          },
        ],
      ),
    );
  }

  static String _areaLabel(AppLocalizations l, BoatPermissionArea area) =>
      switch (area) {
        BoatPermissionArea.recordTrips => l.permRecordTrips,
        BoatPermissionArea.viewDocuments => l.permViewDocuments,
        BoatPermissionArea.manageDocuments => l.permManageDocuments,
        BoatPermissionArea.manageMaintenance => l.permManageMaintenance,
        BoatPermissionArea.manageExpenses => l.permManageExpenses,
      };
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 16,
            color: granted ? AppColors.green : AppColors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: granted ? context.txtPrimary : context.txtSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
