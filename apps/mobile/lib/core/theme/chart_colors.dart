import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

/// A categorical palette for charts.
///
/// [AppColors] has no series palette: its five accents each carry a meaning
/// (cyan = primary, green = good, amber = warning, red = bad), so painting six
/// spend categories with them would say things the data does not. These hues sit
/// in the mid range on purpose — light enough to read on the dark background
/// (#0D1B2A) and dark enough on the light one (#F5F7FA), since every screen is
/// golden-tested in both.
abstract final class ChartColors {
  /// Distinct in order, so neighbouring rows never share a hue.
  static const series = <Color>[
    AppColors.cyan, // #4DA8DA
    AppColors.amber, // #F39C12
    Color(0xFF9B7EDE), // violet
    Color(0xFF1ABC9C), // seafoam
    Color(0xFF5B7FD4), // indigo
    AppColors.red, // #E74C3C
    Color(0xFFE77CA3), // rose
    Color(0xFF7F8C9B), // slate
  ];

  /// The colour for a cost category key, as the API spells it.
  ///
  /// Stable across rebuilds and across periods: a category must not change
  /// colour because a different month is selected. Keys the owner invented hash
  /// into the series instead of all collapsing onto one accent.
  static Color forCostCategory(String key) => switch (key) {
        'combustible' => AppColors.amber,
        'amarre' => AppColors.cyan,
        'seguro' => const Color(0xFF5B7FD4),
        'reparación' => AppColors.red, // i18n-exempt: API value
        'limpieza' => const Color(0xFF1ABC9C),
        'maintenance' => const Color(0xFF9B7EDE),
        'documents' => const Color(0xFFE77CA3),
        'otros' => const Color(0xFF7F8C9B),
        _ => series[key.hashCode.abs() % series.length],
      };
}
