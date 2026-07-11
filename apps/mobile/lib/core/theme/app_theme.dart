import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.cyan,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyan,
          secondary: AppColors.green,
          surface: AppColors.darkSurface,
          error: AppColors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
          onError: Colors.white,
        ),
        textTheme: AppTypography.darkTextTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.cyan,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.cyan,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.glassWhite,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.glassBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cyan, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.red, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.cyan,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.glassBorder,
          thickness: 0.5,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.cyan,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.glassWhite,
          selectedColor: AppColors.cyan.withValues(alpha: 0.2),
          side: const BorderSide(color: AppColors.glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.cyan,
        scaffoldBackgroundColor: AppColors.lightBackground,
        colorScheme: const ColorScheme.light(
          primary: AppColors.cyan,
          secondary: AppColors.green,
          error: AppColors.red,
          onSecondary: Colors.white,
          onSurface: AppColors.textLight,
        ),
        textTheme: AppTypography.lightTextTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.cyan,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: const BorderSide(color: AppColors.cyan),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.lightDivider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.lightDivider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cyan, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.red),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.cyan,
          unselectedItemColor: AppColors.textLightSecondary,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.lightDivider,
          thickness: 0.5,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.cyan,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.lightSurface,
          selectedColor: AppColors.cyan.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );
}
