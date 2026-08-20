import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/theme_colors.dart';
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

  /// Takes a context because each accent has a light and a dark value; a
  /// const getter could only ever be right in one theme.
  Color color(BuildContext context) => switch (this) {
        WeatherCondition.clear => context.caution,
        WeatherCondition.partlyCloudy => context.inkMuted,
        WeatherCondition.cloudy => context.inkMuted,
        WeatherCondition.fog => context.inkMuted,
        WeatherCondition.drizzle => context.accent,
        WeatherCondition.rain => context.accent,
        WeatherCondition.snow => context.accent,
        WeatherCondition.thunderstorm => context.caution,
        WeatherCondition.unknown => context.inkMuted,
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

/// Converts wind direction degrees to a localized 8-point cardinal label.
/// Localized because the letters are not universal: west is W in English and
/// O (oeste) in Spanish.
String cardinalDirection(AppLocalizations l, double degrees) {
  final labels = [
    l.dirN,
    l.dirNE,
    l.dirE,
    l.dirSE,
    l.dirS,
    l.dirSW,
    l.dirW,
    l.dirNW
  ];
  final index = ((degrees + 22.5) / 45).floor() % 8;
  return labels[index];
}

/// Qualitative reading of a wind speed in knots, on the same thresholds as
/// [windColor] so the word and the color never disagree.
String windScaleLabel(AppLocalizations l, double knots) => switch (knots) {
      < 10 => l.calm,
      < 20 => l.moderate,
      _ => l.rough,
    };

/// Qualitative reading of a wave height in meters, on [waveColor]'s thresholds.
String waveScaleLabel(AppLocalizations l, double meters) => switch (meters) {
      < 0.5 => l.calm,
      < 1.5 => l.moderate,
      _ => l.rough,
    };
