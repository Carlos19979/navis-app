import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final dateLabel = weather.date != null
        ? NavisDateUtils.formatRelative(weather.date!)
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: Text(
                weather.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${weather.temperature.toStringAsFixed(0)}°C',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.cyan,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${weather.windSpeed.toStringAsFixed(0)} kt',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(
              _weatherIcon(weather.description),
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
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
}
