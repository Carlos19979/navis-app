import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class BoatDetailScreen extends ConsumerWidget {
  const BoatDetailScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boatAsync = ref.watch(boatProvider(boatId));

    return boatAsync.when(
      loading: () => const Scaffold(body: NavisLoading()),
      error: (error, stack) => Scaffold(
        appBar: const NavisAppBar(title: 'Boat', showBack: true),
        body: NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(boatProvider(boatId)),
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _BoatSliverAppBar(boat: boat),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _InfoSection(boat: boat),
                const SizedBox(height: 24),
                _ActionTile(
                  icon: Icons.description_outlined,
                  title: 'Documents',
                  subtitle: 'Certificates, insurance, inspections',
                  color: AppColors.cyan,
                  onTap: () => context.push('/boats/${boat.id}/documents'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.route_outlined,
                  title: 'Logbook',
                  subtitle: 'Trip history and statistics',
                  color: AppColors.green,
                  onTap: () => context.push('/boats/${boat.id}/trips'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Boat',
                  subtitle: 'Modify boat details',
                  color: AppColors.amber,
                  onTap: () => context.push('/boats/${boat.id}/edit'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.delete_outlined,
                  title: 'Delete Boat',
                  subtitle: 'Remove this boat permanently',
                  color: AppColors.red,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/boats/${boat.id}/record'),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Trip'),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Boat'),
        content: Text(
          'Are you sure you want to delete "${boat.name}"? '
          'This will also remove all associated documents and trips.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
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
                      content: Text('Failed to delete: $e'),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: const Text('Delete'),
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
      backgroundColor: AppColors.navy,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Go back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/boats');
          }
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          boat.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (boat.photoUrl != null && boat.photoUrl!.isNotEmpty)
              Semantics(
                label: 'Boat photo',
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
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
      color: AppColors.darkCard,
      child: const Center(
        child: Icon(
          Icons.sailing,
          size: 64,
          color: AppColors.textSecondary,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.tag,
              label: 'Registration',
              value: boat.registration,
            ),
            const Divider(height: 20),
            _DetailRow(
              icon: Icons.category_outlined,
              label: 'Type',
              value: boat.type[0].toUpperCase() + boat.type.substring(1),
            ),
            const Divider(height: 20),
            _DetailRow(
              icon: Icons.straighten,
              label: 'Length',
              value: '${boat.lengthMeters} m',
            ),
            if (boat.homePort != null) ...[
              const Divider(height: 20),
              _DetailRow(
                icon: Icons.anchor,
                label: 'Home Port',
                value: boat.homePort!,
              ),
            ],
          ],
        ),
      ),
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
        Icon(icon, size: 20, color: AppColors.textSecondary),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
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
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
