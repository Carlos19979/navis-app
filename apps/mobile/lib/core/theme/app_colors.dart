import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const navy = Color(0xFF1B2A4A);
  static const cyan = Color(0xFF4DA8DA);
  static const green = Color(0xFF2ECC71);
  static const amber = Color(0xFFF39C12);
  static const red = Color(0xFFE74C3C);

  // Extended accent palette
  static const cyanLight = Color(0xFF6BC5E8);
  static const teal = Color(0xFF0D2137);
  static const deepNavy = Color(0xFF0A1628);

  // Dark theme surfaces
  static const darkBackground = Color(0xFF0D1B2A);
  static const darkSurface = Color(0xFF1B2A4A);
  static const darkCard = Color(0xFF243352);
  static const darkDivider = Color(0xFF2D3F5E);
  static const darkSurfaceElevated = Color(0xFF253A5E);

  // Light theme surfaces
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightDivider = Color(0xFFE0E4EA);

  // Text
  static const textPrimary = Color(0xFFE8EDF3);
  static const textSecondary = Color(0xFF8899AA);
  static const textLight = Color(0xFF1B2A4A);
  static const textLightSecondary = Color(0xFF5A6B7F);

  // Glass tokens
  static const glassWhite = Color(0x14FFFFFF);
  static const glassBorder = Color(0x29FFFFFF);
  static const glassOverlay = Color(0x0AFFFFFF);
  static const glassHighlight = Color(0x1FFFFFFF);

  // Gradients
  static const oceanGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1628), Color(0xFF0D2137)],
  );

  static const lightOceanGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F7FA), Color(0xFFE8EDF3)],
  );

  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2A4A), Color(0xFF1E3355)],
  );

  static const cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A8FBF), Color(0xFF4DA8DA)],
  );

  static const cyanGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4DA8DA), Color(0xFF6BC5E8)],
  );

  static const redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD63031), Color(0xFFE74C3C)],
  );

  static const greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
  );

  static const amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE67E22), Color(0xFFF39C12)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x14FFFFFF), Color(0x0AFFFFFF)],
  );
}
