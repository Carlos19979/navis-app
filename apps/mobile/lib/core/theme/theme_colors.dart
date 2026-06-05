import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

/// Theme-aware semantic colors. Use these instead of the dark-only
/// [AppColors.textPrimary] / [AppColors.textSecondary] constants so text reads
/// correctly in both light and dark mode.
extension ThemeColorsX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Primary text/icon color (near-white on dark, dark navy on light).
  Color get txtPrimary =>
      isDarkMode ? AppColors.textPrimary : AppColors.textLight;

  /// Secondary/muted text color.
  Color get txtSecondary =>
      isDarkMode ? AppColors.textSecondary : AppColors.textLightSecondary;

  /// Translucent surface fill for inline "glass" containers (search fields,
  /// chips, etc.). Subtle light overlay on dark, subtle dark tint on light.
  Color get glassBg =>
      isDarkMode ? AppColors.glassWhite : const Color(0x0F1B2A4A); // navy @ ~6%

  /// Border color for glass containers.
  Color get glassBorderColor =>
      isDarkMode ? AppColors.glassBorder : AppColors.lightDivider;

  /// Background for modal surfaces (dialogs, bottom sheets, refresh spinners).
  Color get dialogSurface =>
      isDarkMode ? AppColors.darkSurface : AppColors.lightSurface;

  /// Background for elevated modal surfaces (menus, elevated sheets).
  Color get dialogSurfaceElevated =>
      isDarkMode ? AppColors.darkSurfaceElevated : AppColors.lightCard;
}
