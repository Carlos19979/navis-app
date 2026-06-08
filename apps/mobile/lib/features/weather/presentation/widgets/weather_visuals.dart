import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// A weather condition derived from a WMO weather code, with an icon and color.
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown;

  /// Maps a WMO weather code (as returned by Open-Meteo) to a condition.
  static WeatherCondition fromCode(int code) => switch (code) {
        0 => WeatherCondition.clear,
        1 || 2 => WeatherCondition.partlyCloudy,
        3 => WeatherCondition.cloudy,
        45 || 48 => WeatherCondition.fog,
        51 || 53 || 55 || 56 || 57 => WeatherCondition.drizzle,
        61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => WeatherCondition.rain,
        71 || 73 || 75 || 77 || 85 || 86 => WeatherCondition.snow,
        95 || 96 || 99 => WeatherCondition.thunderstorm,
        _ => WeatherCondition.unknown,
      };

  IconData get icon => switch (this) {
        WeatherCondition.clear => Icons.wb_sunny_rounded,
        WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
        WeatherCondition.cloudy => Icons.cloud_rounded,
        WeatherCondition.fog => Icons.blur_on_rounded,
        WeatherCondition.drizzle => Icons.grain_rounded,
        WeatherCondition.rain => Icons.water_drop_rounded,
        WeatherCondition.snow => Icons.ac_unit_rounded,
        WeatherCondition.thunderstorm => Icons.flash_on_rounded,
        WeatherCondition.unknown => Icons.cloud_outlined,
      };

  Color get color => switch (this) {
        WeatherCondition.clear => AppColors.amber,
        WeatherCondition.partlyCloudy => AppColors.cyanLight,
        WeatherCondition.cloudy => AppColors.cyanLight,
        WeatherCondition.fog => AppColors.cyanLight,
        WeatherCondition.drizzle => AppColors.cyan,
        WeatherCondition.rain => AppColors.cyan,
        WeatherCondition.snow => AppColors.cyanLight,
        WeatherCondition.thunderstorm => AppColors.amber,
        WeatherCondition.unknown => AppColors.cyanLight,
      };

  String label(AppLocalizations l) => switch (this) {
        WeatherCondition.clear => l.wcClear,
        WeatherCondition.partlyCloudy => l.wcPartlyCloudy,
        WeatherCondition.cloudy => l.wcCloudy,
        WeatherCondition.fog => l.wcFog,
        WeatherCondition.drizzle => l.wcDrizzle,
        WeatherCondition.rain => l.wcRain,
        WeatherCondition.snow => l.wcSnow,
        WeatherCondition.thunderstorm => l.wcThunderstorm,
        WeatherCondition.unknown => l.wcUnknown,
      };
}

/// Returns a localized weather description for a WMO weather [code].
String weatherDescription(AppLocalizations l, int code) =>
    WeatherCondition.fromCode(code).label(l);

/// Color scale for wind speed in knots (calm → strong).
Color windColor(double knots) {
  if (knots < 10) return AppColors.green;
  if (knots < 20) return AppColors.amber;
  return AppColors.red;
}

/// Color scale for wave height in meters (calm → rough).
Color waveColor(double meters) {
  if (meters < 0.5) return AppColors.green;
  if (meters < 1.5) return AppColors.cyan;
  if (meters < 2.5) return AppColors.amber;
  return AppColors.red;
}

/// Converts wind direction degrees to an 8-point cardinal label.
String cardinalDirection(double degrees) {
  const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((degrees + 22.5) / 45).floor() % 8;
  return labels[index];
}
