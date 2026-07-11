import 'package:flutter/widgets.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

/// Reusable shadow presets. The app conveys depth with soft shadows (Material
/// elevation is 0 everywhere); these extract the repeated BoxShadow lists.
abstract final class Shadows {
  /// Soft shadow under glass/solid cards. Pass the theme brightness so the
  /// card shadow is stronger on dark, subtle on light.
  static List<BoxShadow> card({required bool isDark}) => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: isDark ? 0.15 : 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Cyan glow under primary actions (buttons, FAB).
  static List<BoxShadow> glowCyan = [
    BoxShadow(
      color: AppColors.cyan.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Red glow under destructive actions.
  static List<BoxShadow> glowRed = [
    BoxShadow(
      color: AppColors.red.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Shadow under the floating bottom navigation pill.
  static List<BoxShadow> nav = [
    BoxShadow(
      color: AppColors.deepNavy.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
