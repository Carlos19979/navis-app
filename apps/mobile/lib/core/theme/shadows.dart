import 'package:flutter/widgets.dart';

import 'package:navis_mobile/core/theme/palette.dart';

/// The two shadows the app is allowed to draw.
///
/// Hierarchy is carried by **hairlines and space**, not by elevation: a soft
/// navy shadow under every card is what gave the light theme its grey, smudged
/// look, and it cost a blur pass per card. So `Shadows.card` is gone — a card
/// separates itself with `context.hairline`.
///
/// What is left are the two things that genuinely float above the page and need
/// to read as detached from it.
abstract final class Shadows {
  /// Under the floating bottom-nav pill.
  static List<BoxShadow> nav({required bool isDark}) => [
        BoxShadow(
          color: (isDark ? Palette.navyDeep : Palette.ink)
              .withValues(alpha: isDark ? 0.34 : 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// Under the primary floating action, to lift it off the canvas. Tinted with
  /// the accent so it reads as a glow rather than dirt.
  static List<BoxShadow> action({required bool isDark}) => [
        BoxShadow(
          color: Palette.accentBright.withValues(alpha: isDark ? 0.34 : 0.24),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Under a destructive floating action.
  static List<BoxShadow> danger({required bool isDark}) => [
        BoxShadow(
          color: Palette.criticalBright.withValues(alpha: isDark ? 0.30 : 0.20),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
