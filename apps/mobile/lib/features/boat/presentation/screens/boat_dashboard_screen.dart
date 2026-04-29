import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/weather/presentation/providers/weather_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_header.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
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
      backgroundColor: Colors.transparent,
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
                  return const SizedBox(height: 100);
                }
                final boat = boats[index - 1];
                return _BoatCard(boat: boat, index: index - 1);
              },
            ),
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.cyanGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.go('/boats/new'),
          tooltip: 'Add new boat',
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            semanticLabel: 'Add new boat',
          ),
        ),
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NavisCard(
            borderColor: AppColors.cyan.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  color: AppColors.cyan.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${weather.temperature.toStringAsFixed(0)}\u00B0',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              weather.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.air,
                            size: 14,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${weather.windSpeed.toStringAsFixed(0)} kt',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.waves,
                            size: 14,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${weather.waveHeight.toStringAsFixed(1)} m',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: -0.1, end: 0, duration: 400.ms);
      },
    );
  }
}

class _BoatCard extends ConsumerWidget {
  const _BoatCard({required this.boat, required this.index});

  final Boat boat;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(boatDocumentSummaryProvider(boat.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NavisCard(
        padding: EdgeInsets.zero,
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
                    label: boat.type[0].toUpperCase() +
                        boat.type.substring(1),
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
            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: NavisButton(
                      label: 'Documents',
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
                      label: 'Logbook',
                      icon: Icons.route_outlined,
                      variant: NavisButtonVariant.secondary,
                      compact: true,
                      onPressed: () =>
                          context.push('/boats/${boat.id}/trips'),
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
        color: AppColors.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
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
