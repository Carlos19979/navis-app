import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final dateLabel = weather.date != null
        ? NavisDateUtils.formatRelative(weather.date!)
        : '-';
    final iconData = _weatherIcon(weather.description);
    final iconColor = _weatherIconColor(weather.description);

    return NavisCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Weather icon in colored glass circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Date label
          SizedBox(
            width: 70,
            child: Text(
              dateLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),

          // Description
          Expanded(
            child: Text(
              weather.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),

          // Temperature and wind
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${weather.temperature.toStringAsFixed(0)}°C',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${weather.windSpeed.toStringAsFixed(0)} kt',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _weatherIcon(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('sun') || lower.contains('clear')) {
      return Icons.wb_sunny;
    }
    if (lower.contains('cloud')) return Icons.cloud;
    if (lower.contains('rain')) return Icons.grain;
    if (lower.contains('storm') || lower.contains('thunder')) {
      return Icons.flash_on;
    }
    if (lower.contains('snow')) return Icons.ac_unit;
    if (lower.contains('fog') || lower.contains('mist')) return Icons.blur_on;
    return Icons.cloud_outlined;
  }

  Color _weatherIconColor(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('sun') || lower.contains('clear')) {
      return AppColors.amber;
    }
    if (lower.contains('rain') ||
        lower.contains('storm') ||
        lower.contains('thunder')) {
      return AppColors.cyan;
    }
    if (lower.contains('snow')) return AppColors.cyanLight;
    return AppColors.textSecondary;
  }
}
