import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/weather/domain/entities/weather.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key, required this.days});

  final List<Weather> days;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < days.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.glassBorder.withValues(alpha: 0.3),
                indent: 16,
                endIndent: 16,
              ),
            _ForecastRow(weather: days[i]),
          ],
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.textPrimary : AppColors.textLight;
    final secondaryColor =
        isDark ? AppColors.textSecondary : AppColors.textLightSecondary;
    final dateLabel = weather.date != null
        ? NavisDateUtils.formatRelative(weather.date!)
        : '-';
    final iconData = _weatherIcon(weather.description);
    final iconColor = _weatherIconColor(weather.description, isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  weather.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondaryColor,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${weather.temperature.toStringAsFixed(0)}°C',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatChip(
                icon: Icons.air,
                value: '${weather.windSpeed.toStringAsFixed(0)} kt',
                color: _windColor(weather.windSpeed),
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.navigation,
                value: _windDirectionLabel(
                  weather.windDirection,
                ),
                color: secondaryColor,
                iconRotation: weather.windDirection,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.waves,
                value: '${weather.waveHeight.toStringAsFixed(1)} m',
                color: _waveColor(weather.waveHeight),
              ),
              if (weather.humidity != null) ...[
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.water_drop,
                  value: '${weather.humidity}%',
                  color: AppColors.cyan,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Color _windColor(double knots) {
    if (knots < 10) return AppColors.green;
    if (knots < 20) return AppColors.amber;
    return AppColors.red;
  }

  static Color _waveColor(double meters) {
    if (meters < 1.0) return AppColors.green;
    if (meters < 2.0) return AppColors.amber;
    return AppColors.red;
  }

  static String _windDirectionLabel(double degrees) {
    const labels = [
      'N',
      'NE',
      'E',
      'SE',
      'S',
      'SW',
      'W',
      'NW',
    ];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return labels[index];
  }

  static IconData _weatherIcon(String description) {
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
    if (lower.contains('fog') || lower.contains('mist')) {
      return Icons.blur_on;
    }
    return Icons.cloud_outlined;
  }

  static Color _weatherIconColor(String description, bool isDark) {
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
    return isDark ? AppColors.textSecondary : AppColors.textLightSecondary;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
    this.iconRotation,
  });

  final IconData icon;
  final String value;
  final Color color;
  final double? iconRotation;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconRotation != null)
              Transform.rotate(
                angle: iconRotation! * 3.14159 / 180,
                child: Icon(icon, size: 12, color: color),
              )
            else
              Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
