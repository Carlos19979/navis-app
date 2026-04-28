import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class TripStatsScreen extends ConsumerWidget {
  const TripStatsScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tripsAsync = ref.watch(boatTripsProvider(boatId));

    return Scaffold(
      appBar: NavisAppBar(
        title: l10n?.tripStatistics ?? 'Trip Statistics',
      ),
      body: tripsAsync.when(
        loading: () => const NavisShimmer(itemHeight: 120),
        error: (error, _) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(boatTripsProvider(boatId)),
        ),
        data: (trips) {
          final stats = ref.watch(tripStatsProvider(trips));

          final ports = <String>{};
          for (final trip in trips) {
            ports.add(trip.departurePort);
            if (trip.arrivalPort != null) ports.add(trip.arrivalPort!);
          }

          double totalFuel = 0;
          double totalEngine = 0;
          double maxSpeed = 0;
          for (final trip in trips) {
            totalFuel += trip.fuelConsumedL ?? 0;
            totalEngine += trip.engineHours ?? 0;
            if ((trip.maxSpeedKnots ?? 0) > maxSpeed) {
              maxSpeed = trip.maxSpeedKnots ?? 0;
            }
          }

          final thisYear = DateTime.now().year;
          final tripsThisYear = trips
              .where((t) => t.departureTime.year == thisYear)
              .toList();
          final yearStats = ref.watch(tripStatsProvider(tripsThisYear));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(
                label: l10n?.allTime ?? 'All Time',
              ),
              const SizedBox(height: 8),
              _StatsGrid(children: [
                _StatCard(
                  icon: Icons.route,
                  value: stats.totalTrips.toString(),
                  label: l10n?.totalTrips ?? 'Trips',
                  color: AppColors.cyan,
                ),
                _StatCard(
                  icon: Icons.straighten,
                  value: stats.totalDistanceNm.toStringAsFixed(1),
                  label: l10n?.totalDistanceNm ?? 'NM sailed',
                  color: AppColors.green,
                ),
                _StatCard(
                  icon: Icons.schedule,
                  value: stats.totalHours.toStringAsFixed(1),
                  label: l10n?.totalHoursAtSea ?? 'Hours at sea',
                  color: AppColors.amber,
                ),
                _StatCard(
                  icon: Icons.anchor,
                  value: ports.length.toString(),
                  label: l10n?.portsVisited ?? 'Ports visited',
                  color: AppColors.cyan,
                ),
                _StatCard(
                  icon: Icons.speed,
                  value: maxSpeed > 0
                      ? '${maxSpeed.toStringAsFixed(1)} kn'
                      : '-',
                  label: l10n?.topSpeed ?? 'Top speed',
                  color: AppColors.red,
                ),
                _StatCard(
                  icon: Icons.local_gas_station,
                  value: totalFuel > 0
                      ? '${totalFuel.toStringAsFixed(0)} L'
                      : '-',
                  label: l10n?.fuelConsumed ?? 'Fuel consumed',
                  color: AppColors.amber,
                ),
              ]),
              const SizedBox(height: 24),
              if (totalEngine > 0) ...[
                _StatRow(
                  icon: Icons.engineering,
                  label: l10n?.engineHoursTotal ?? 'Engine hours',
                  value: '${totalEngine.toStringAsFixed(1)} h',
                ),
                const SizedBox(height: 8),
              ],
              if (stats.totalDistanceNm > 0 && stats.totalHours > 0)
                _StatRow(
                  icon: Icons.speed_outlined,
                  label: l10n?.avgSpeed ?? 'Avg speed',
                  value:
                      '${(stats.totalDistanceNm / stats.totalHours).toStringAsFixed(1)} kn',
                ),
              const SizedBox(height: 24),
              _SectionTitle(
                label: '$thisYear ${l10n?.yearInReview ?? 'Year in Review'}',
              ),
              const SizedBox(height: 8),
              _StatsGrid(children: [
                _StatCard(
                  icon: Icons.route,
                  value: yearStats.totalTrips.toString(),
                  label: l10n?.tripsLabel ?? 'Trips',
                  color: AppColors.cyan,
                ),
                _StatCard(
                  icon: Icons.straighten,
                  value: yearStats.totalDistanceNm.toStringAsFixed(1),
                  label: l10n?.distanceNmLabel ?? 'NM',
                  color: AppColors.green,
                ),
                _StatCard(
                  icon: Icons.schedule,
                  value: yearStats.totalHours.toStringAsFixed(1),
                  label: l10n?.hoursLabel ?? 'Hours',
                  color: AppColors.amber,
                ),
              ]),
              const SizedBox(height: 16),
              _MonthlyChart(trips: tripsThisYear),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children
          .map((child) => SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 3,
                child: child,
              ))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.cyan, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.trips});

  final List trips;

  @override
  Widget build(BuildContext context) {
    final monthCounts = List.filled(12, 0);
    for (final trip in trips) {
      final month = trip.departureTime.month - 1;
      monthCounts[month]++;
    }

    final maxCount =
        monthCounts.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.monthlyActivity ??
                  'Monthly Activity',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (i) {
                  final fraction = monthCounts[i] / maxCount;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (monthCounts[i] > 0)
                            Text(
                              '${monthCounts[i]}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.cyan,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            height: (fraction * 60).clamp(4.0, 60.0),
                            decoration: BoxDecoration(
                              color: monthCounts[i] > 0
                                  ? AppColors.cyan
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            months[i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
