import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/trips/${trip.id}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flight_takeoff,
                      size: 16, color: AppColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.departurePort,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (trip.arrivalPort != null) ...[
                    const Icon(Icons.arrow_forward,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    const Icon(Icons.flight_land,
                        size: 16, color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.arrivalPort!,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                NavisDateUtils.formatDateTime(trip.departureTime),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (trip.distanceNm != null)
                    _Chip(
                      icon: Icons.straighten,
                      label: DistanceUtils.formatDistance(trip.distanceNm!),
                    ),
                  if (trip.duration != null)
                    _Chip(
                      icon: Icons.schedule,
                      label: NavisDateUtils.formatDuration(trip.duration!),
                    ),
                  if (trip.avgSpeedKnots != null)
                    _Chip(
                      icon: Icons.speed,
                      label: DistanceUtils.formatSpeed(trip.avgSpeedKnots!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
