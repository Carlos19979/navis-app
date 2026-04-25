import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';

class StatsSummary extends StatelessWidget {
  const StatsSummary({super.key, required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: 'Trips',
              value: '${stats.totalTrips}',
              icon: Icons.route,
            ),
            Container(
              width: 1,
              height: 40,
              color: AppColors.darkDivider,
            ),
            _StatItem(
              label: 'Distance',
              value: '${stats.totalDistanceNm.toStringAsFixed(0)} NM',
              icon: Icons.straighten,
            ),
            Container(
              width: 1,
              height: 40,
              color: AppColors.darkDivider,
            ),
            _StatItem(
              label: 'Hours',
              value: stats.totalHours.toStringAsFixed(0),
              icon: Icons.schedule,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.cyan),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
