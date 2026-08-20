import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/palette.dart';

/// A categorical palette for charts.
///
/// The semantic accents each carry a meaning (accent = primary, positive =
/// good, caution = warning, critical = bad), so painting six spend categories
/// with them would say things the data does not. These hues sit in the mid
/// range on purpose — light enough to read on the dark canvas and dark enough
/// on the light one, since every screen is golden-tested in both.
///
/// **Fill role only.** These are for bars, dots and swatches, never for text:
/// several of them are under 4.5:1 on white, exactly like the brand accents
/// (see [Palette]). A chart legend paints a small swatch in the series colour
/// and sets its label in `context.ink` / `context.inkMuted`, which is both
/// legible and how the rest of the app reads.
abstract final class ChartColors {
  /// Distinct in order, so neighbouring rows never share a hue.
  static const series = <Color>[
    Palette.accentBright, // #4DA8DA
    Palette.cautionBright, // #F39C12
    Color(0xFF9B7EDE), // violet
    Color(0xFF1ABC9C), // seafoam
    Color(0xFF5B7FD4), // indigo
    Palette.criticalBright, // #E74C3C
    Color(0xFFE77CA3), // rose
    Color(0xFF7F8C9B), // slate
  ];

  /// The colour for a cost category key, as the API spells it.
  ///
  /// Stable across rebuilds and across periods: a category must not change
  /// colour because a different month is selected. Keys the owner invented hash
  /// into the series instead of all collapsing onto one accent.
  static Color forCostCategory(String key) => switch (key) {
        'combustible' => Palette.cautionBright,
        'amarre' => Palette.accentBright,
        'seguro' => const Color(0xFF5B7FD4),
        'reparación' => Palette.criticalBright, // i18n-exempt: API value
        'limpieza' => const Color(0xFF1ABC9C),
        'maintenance' => const Color(0xFF9B7EDE),
        'documents' => const Color(0xFFE77CA3),
        'otros' => const Color(0xFF7F8C9B),
        _ => series[key.hashCode.abs() % series.length],
      };
}
