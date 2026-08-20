// CupertinoPageTransitionsBuilder lives in cupertino.dart on the local SDK
// (3.44) but is re-exported from material.dart on the CI-pinned SDK (3.41.7),
// where this import is therefore unused. Keep it (no `show`) so both toolchains
// resolve the symbol; the ignore covers the CI-only unused-import warning.
// ignore: unnecessary_import, unused_import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/palette.dart';

/// Both themes, built from the same token set so they cannot drift.
///
/// Light is the designed-first theme now; dark is a full first-class variant
/// (every screen is golden-tested in both). The two differ only in which side
/// of each [Palette] ramp they read — there is no light-only or dark-only rule
/// below.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        canvas: Palette.canvasLight,
        surfaceRaised: Palette.surfaceRaisedLight,
        surfaceSunken: Palette.surfaceSunkenLight,
        hairline: Palette.hairlineLight,
        ink: Palette.ink,
        inkMuted: Palette.inkMuted,
        // The *ink* accent, not the bright one: this colour fills the primary
        // button and carries white text on it (5.55:1), and tints links.
        accent: Palette.accentInk,
        critical: Palette.criticalInk,
        textTheme: AppTypography.lightTextTheme,
        statusBarIcons: Brightness.dark,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        canvas: Palette.canvasDark,
        surfaceRaised: Palette.surfaceRaisedDark,
        surfaceSunken: Palette.surfaceSunkenDark,
        hairline: Palette.hairlineDark,
        ink: Palette.inkOnDark,
        inkMuted: Palette.inkMutedOnDark,
        accent: Palette.accentBright,
        critical: Palette.criticalBright,
        textTheme: AppTypography.darkTextTheme,
        statusBarIcons: Brightness.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color canvas,
    required Color surfaceRaised,
    required Color surfaceSunken,
    required Color hairline,
    required Color ink,
    required Color inkMuted,
    required Color accent,
    required Color critical,
    required TextTheme textTheme,
    required Brightness statusBarIcons,
  }) {
    final isDark = brightness == Brightness.dark;

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusControl),
    );
    final surfaceShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusSurface),
    );
    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: accent,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Palette.onAccent,
        secondary: accent,
        onSecondary: Palette.onAccent,
        error: critical,
        onError: Palette.onAccent,
        surface: canvas,
        onSurface: ink,
        surfaceContainerHighest: surfaceSunken,
        outline: hairline,
        outlineVariant: hairline,
      ),
      textTheme: textTheme,

      // The app bar carries no fill of its own: NavisAppBar draws the blurred
      // surface when it needs one. The old theme painted a translucent navy
      // band that read as a mismatched grey stripe above a light body.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: statusBarIcons,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: surfaceShape,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Palette.onAccent,
          disabledBackgroundColor: hairline,
          disabledForegroundColor: inkMuted,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: controlShape,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(double.infinity, 52),
          shape: controlShape,
          side: BorderSide(color: hairline),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Dimens.spaceLg,
          vertical: Dimens.spaceLg,
        ),
        border: inputBorder(hairline, Dimens.hairline),
        enabledBorder: inputBorder(hairline, Dimens.hairline),
        focusedBorder: inputBorder(accent, 2),
        errorBorder: inputBorder(critical, Dimens.hairline),
        focusedErrorBorder: inputBorder(critical, 2),
        labelStyle: textTheme.bodyMedium?.copyWith(color: inkMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: inkMuted),
        errorStyle: textTheme.bodySmall?.copyWith(color: critical),
      ),

      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: Dimens.hairline,
        space: Dimens.hairline,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Palette.onAccent,
        elevation: 0,
        shape: controlShape,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: surfaceShape,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: inkMuted),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Dimens.radiusSurface),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceRaised : Palette.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? ink : Palette.canvasLight,
        ),
        shape: controlShape,
        elevation: 0,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceSunken,
        selectedColor: accent.withValues(alpha: isDark ? 0.20 : 0.10),
        side: BorderSide(color: hairline),
        labelStyle: textTheme.labelLarge?.copyWith(fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusChip),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: inkMuted,
        textColor: ink,
        minVerticalPadding: Dimens.spaceMd,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: hairline,
        circularTrackColor: hairline,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Palette.onAccent
              : (isDark ? inkMuted : Palette.canvasLight),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.all(hairline),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: inkMuted,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accent,
        unselectedItemColor: inkMuted,
        type: BottomNavigationBarType.fixed,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
