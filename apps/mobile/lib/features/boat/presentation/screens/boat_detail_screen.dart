import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

String _localizedBoatType(AppLocalizations l, String type) => switch (type) {
      'sailboat' => l.sailboat,
      'motorboat' => l.motorboat,
      'catamaran' => l.catamaran,
      'other' => l.other,
      _ => type[0].toUpperCase() + type.substring(1),
    };

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
                  _InfoSection(boat: boat)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.05, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),
                  _ActionTile(
                    icon: Icons.description_outlined,
                    title: l.documents,
                    subtitle: l.certificates,
                    color: AppColors.cyan,
                    onTap: () => context.push('/boats/${boat.id}/documents'),
                  ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 400.ms,
                        delay: 50.ms,
                      ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.route_outlined,
                    title: l.logbook,
                    subtitle: l.tripHistory,
                    color: AppColors.green,
                    onTap: () => context.push('/boats/${boat.id}/trips'),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 400.ms,
                        delay: 100.ms,
                      ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.edit_outlined,
                    title: l.editBoat,
                    subtitle: l.modifyBoatDetails,
                    color: AppColors.amber,
                    onTap: () => context.push('/boats/${boat.id}/edit'),
                  ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 400.ms,
                        delay: 150.ms,
                      ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.delete_outlined,
                    title: l.deleteBoat,
                    subtitle: l.removePermanently,
                    color: AppColors.red,
                    onTap: () => _confirmDelete(context, ref),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 400.ms,
                        delay: 200.ms,
                      ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.glassBorder,
            width: 0.5,
          ),
        ),
        title: Text(l.deleteBoat),
        content: Text(l.deleteBoatConfirm(boat.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
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
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
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
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: AppColors.glassWhite,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
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
          style: TextStyle(
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
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
          _glassDivider(),
          _DetailRow(
            icon: Icons.category_outlined,
            label: AppLocalizations.of(context)!.type,
            value: _localizedBoatType(AppLocalizations.of(context)!, boat.type),
          ),
          _glassDivider(),
          _DetailRow(
            icon: Icons.straighten,
            label: AppLocalizations.of(context)!.length,
            value: '${boat.lengthMeters} m',
          ),
          if (boat.homePort != null) ...[
            _glassDivider(),
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

  Widget _glassDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: AppColors.glassBorder,
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
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.cyan),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

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
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
