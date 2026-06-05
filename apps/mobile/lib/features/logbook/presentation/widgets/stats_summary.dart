import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class StatsSummary extends StatelessWidget {
  const StatsSummary({super.key, required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: l.tripsLabel,
            value: '${stats.totalTrips}',
            icon: Icons.route,
          ),
          Container(
            width: 1,
            height: 40,
            color: context.glassBorderColor,
          ),
          _StatItem(
            label: l.distance,
            value: '${stats.totalDistanceNm.toStringAsFixed(0)} NM',
            icon: Icons.straighten,
          ),
          Container(
            width: 1,
            height: 40,
            color: context.glassBorderColor,
          ),
          _StatItem(
            label: l.hoursLabel,
            value: stats.totalHours.toStringAsFixed(0),
            icon: Icons.schedule,
          ),
        ],
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
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: context.glassBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.glassBorderColor,
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 18, color: AppColors.cyan),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.cyan,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.txtSecondary,
              ),
        ),
      ],
    );
  }
}
