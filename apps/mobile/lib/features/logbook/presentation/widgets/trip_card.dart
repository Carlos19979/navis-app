import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/distance_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.go('/trips/${trip.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.cyanGradient.createShader(bounds),
                child: const Icon(
                  Icons.flight_takeoff,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trip.departurePort,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (trip.arrivalPort != null) ...[
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.cyanGlowGradient.createShader(bounds),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.greenGradient.createShader(bounds),
                  child: const Icon(
                    Icons.flight_land,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.arrivalPort!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NavisDateUtils.formatDateTime(trip.departureTime),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (trip.distanceNm != null)
                _GlassPill(
                  icon: Icons.straighten,
                  label: DistanceUtils.formatDistance(trip.distanceNm!),
                ),
              if (trip.duration != null)
                _GlassPill(
                  icon: Icons.schedule,
                  label: NavisDateUtils.formatDuration(trip.duration!),
                ),
              if (trip.avgSpeedKnots != null)
                _GlassPill(
                  icon: Icons.speed,
                  label: DistanceUtils.formatSpeed(trip.avgSpeedKnots!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
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
            Icon(icon, size: 12, color: AppColors.cyan),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
