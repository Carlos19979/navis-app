import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_header.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class BoatDashboardScreen extends ConsumerWidget {
  const BoatDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boatsAsync = ref.watch(boatsProvider);

    return Scaffold(
      appBar: const NavisAppBar(title: 'My Boats'),
      body: boatsAsync.when(
        loading: () => const NavisShimmer(itemCount: 3, itemHeight: 180),
        error: (error, stack) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(boatsProvider),
        ),
        data: (boats) {
          if (boats.isEmpty) {
            return NavisEmptyState(
              icon: Icons.sailing_outlined,
              message: 'No boats yet. Add your first boat!',
              actionLabel: 'Add Boat',
              onAction: () => context.go('/boats/new'),
            );
          }

          return RefreshIndicator(
            color: AppColors.cyan,
            onRefresh: () async {
              ref.invalidate(boatsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: boats.length,
              itemBuilder: (context, index) {
                final boat = boats[index];
                return _BoatCard(boat: boat);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/boats/new'),
        tooltip: 'Add new boat',
        child: const Icon(Icons.add, semanticLabel: 'Add new boat'),
      ),
    );
  }
}

class _BoatCard extends StatelessWidget {
  const _BoatCard({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/boats/${boat.id}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BoatHeader(boat: boat),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _InfoChip(
                    icon: Icons.straighten,
                    label: '${boat.lengthMeters}m',
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: boat.type,
                  ),
                  if (boat.homePort != null) ...[
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.anchor,
                      label: boat.homePort!,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.go('/boats/${boat.id}/documents/new'),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Documents'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/boats/${boat.id}/trips'),
                      icon: const Icon(Icons.route_outlined, size: 18),
                      label: const Text('Trips'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
