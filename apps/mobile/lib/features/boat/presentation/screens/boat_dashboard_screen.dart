import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_header.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final boatsAsync = ref.watch(boatsProvider);

    return Scaffold(
      appBar: const NavisAppBar(title: 'My Boats'),
      body: boatsAsync.when(
        loading: () => const NavisShimmer(itemHeight: 180),
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
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: boats.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _WeatherSummary();
                }
                if (index == boats.length + 1) {
                  return const SizedBox(height: 80);
                }
                final boat = boats[index - 1];
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

class _WeatherSummary extends ConsumerWidget {
  const _WeatherSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(currentWeatherProvider);

    return weatherAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (weather) {
        if (weather == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  color: AppColors.cyan,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather.temperature.toStringAsFixed(0)}'
                        '\u00B0C \u2014 ${weather.description}',
                        style:
                            Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Wind '
                        '${weather.windSpeed.toStringAsFixed(0)}'
                        ' kt \u00B7 Waves '
                        '${weather.waveHeight.toStringAsFixed(1)}'
                        ' m',
                        style:
                            Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoatCard extends ConsumerWidget {
  const _BoatCard({required this.boat});

  final Boat boat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(boatDocumentSummaryProvider(boat.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/boats/${boat.id}'),
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
                          label: 'Expired',
                          color: AppColors.red,
                        ),
                      if (value.critical > 0)
                        _StatusBadge(
                          count: value.critical,
                          label: 'Critical',
                          color: AppColors.red,
                        ),
                      if (value.warning > 0)
                        _StatusBadge(
                          count: value.warning,
                          label: 'Warning',
                          color: AppColors.amber,
                        ),
                      if (value.ok > 0)
                        _StatusBadge(
                          count: value.ok,
                          label: 'Valid',
                          color: AppColors.green,
                        ),
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
                          context.push('/boats/${boat.id}/documents'),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Documents'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/boats/${boat.id}/trips'),
                      icon: const Icon(Icons.route_outlined, size: 18),
                      label: const Text('Logbook'),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
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
