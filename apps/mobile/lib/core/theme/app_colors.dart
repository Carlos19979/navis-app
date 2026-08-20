import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/palette.dart';

/// **Legacy.** The pre-redesign colour surface, kept alive because ~570 call
/// sites still read from it while the screens are reworked.
///
/// It is a thin shim over [Palette] now, so the values move with the design
/// system instead of drifting from it. Two rules while it exists:
///
///  * **Do not add anything here.** New colours go in [Palette] and are exposed
///    through the `ThemeColorsX` getters.
///  * **Do not use it in new code.** `AppColors.cyan` is theme-blind: it is the
///    bright accent, which fails WCAG AA as text on the light canvas (2.65:1).
///    Use `context.accent` for text and icons, `context.accentFill` for fills.
///
/// The `glass*` values are the exception that will outlive the rest: a
/// translucent white veil is the right thing over a *photograph* (the boat
/// header pill, map overlays), where there is real detail behind it.
class AppColors {
  AppColors._();

  // Primary palette → Palette accents (identical values).
  static const navy = Palette.navy;
  static const cyan = Palette.accentBright;
  static const green = Palette.positiveBright;
  static const amber = Palette.caution;
  static const red = Palette.criticalBright;

  // Extended accent palette
  static const cyanLight = Color(0xFF6BC5E8);
  static const teal = Color(0xFF0D2137);
  static const deepNavy = Palette.navyDeep;

  // Dark theme surfaces
  static const darkBackground = Palette.canvasDark;
  static const darkSurface = Palette.surfaceRaisedDark;
  static const darkCard = Palette.surfaceRaisedDark;
  static const darkDivider = Palette.hairlineDark;
  static const darkSurfaceElevated = Palette.surfaceRaisedDark;

  // Light theme surfaces
  static const lightBackground = Palette.canvasLight;
  static const lightSurface = Palette.surfaceRaisedLight;
  static const lightCard = Palette.surfaceRaisedLight;
  static const lightDivider = Palette.hairlineLight;

  // Text
  static const textPrimary = Palette.inkOnDark;
  static const textSecondary = Palette.inkMutedOnDark;
  static const textLight = Palette.ink;
  static const textLightSecondary = Palette.inkMuted;

  // Glass tokens — translucent on purpose: these sit over photos and maps.
  static const glassWhite = Color(0x14FFFFFF);
  static const glassBorder = Color(0x29FFFFFF);
  static const glassOverlay = Color(0x0AFFFFFF);
  static const glassHighlight = Color(0x1FFFFFFF);

  // Gradients. The decorative ones are now flat: on a white canvas a gradient
  // reads as a smudge. Only the primary action keeps a real one.
  static const cyanGradient = Palette.accentGradient;
  static const cyanGlowGradient = Palette.accentGradientDark;
  static const oceanGradient = Palette.oceanDark;

  static const lightOceanGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Palette.canvasLight, Palette.canvasLight],
  );

  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Palette.surfaceRaisedDark, Palette.surfaceRaisedDark],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Palette.surfaceRaisedDark, Palette.surfaceRaisedDark],
  );

  static const redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Palette.criticalInk, Palette.criticalBright],
  );

  static const greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Palette.positiveInk, Palette.positiveBright],
  );

  static const amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Palette.caution, Palette.caution],
  );
}
