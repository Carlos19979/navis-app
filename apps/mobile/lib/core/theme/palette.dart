import 'package:flutter/painting.dart';

/// Raw, context-free colour values. **Screens must not import this file** —
/// they read colours through the `ThemeColorsX` getters in `theme_colors.dart`,
/// which pick the right side of each ramp for the active theme.
///
/// Two ramps per accent, and that is the whole point of this file. The five
/// original brand accents were chosen against the dark navy background and
/// none of them is legible as text on white:
///
/// | accent          | on #0D1B2A | on #FFFFFF |
/// |-----------------|-----------:|-----------:|
/// | cyan  #4DA8DA   |     6.57:1 | **2.65:1** |
/// | green #2ECC71   |     8.28:1 | **2.10:1** |
/// | amber #F39C12   |     7.93:1 | **2.19:1** |
/// | red   #E74C3C   |     4.55:1 | **3.82:1** |
///
/// So each accent exists twice: an `*Ink` value that clears WCAG AA (4.5:1) on
/// the light canvas and is used for **text and icons**, and a `*Bright` value
/// used for **fills, bars and chart series** — where the contrast requirement
/// is against an adjacent shape, not a glyph — and for text on dark, where the
/// bright value already passes.
///
/// **Amber is the exception, and it has no ink twin.** Cyan, green and red all
/// have a darker shade that is recognisably the same colour; amber does not.
/// Getting `#F39C12` to 4.5:1 on white means `#A86600`, which nobody would call
/// amber — it is brown. So the caution accent stays the brand amber at full
/// saturation and is never bare text on a light surface: a caution *stated in
/// words* is a filled chip with navy ink on it (7.32:1), which shows more amber
/// than the old tinted-text treatment did, not less.
abstract final class Palette {
  // ── Light canvas ────────────────────────────────────────────────────────
  static const canvasLight = Color(0xFFFFFFFF);
  static const surfaceSunkenLight = Color(0xFFF7F8FA);
  static const surfaceRaisedLight = Color(0xFFFFFFFF);
  static const hairlineLight = Color(0xFFE6E9EF);

  // ── Dark canvas ─────────────────────────────────────────────────────────
  static const canvasDark = Color(0xFF0B1420);
  static const surfaceSunkenDark = Color(0xFF111E2E);
  static const surfaceRaisedDark = Color(0xFF16263A);
  static const hairlineDark = Color(0xFF23364E);

  // ── Ink (text) ──────────────────────────────────────────────────────────
  /// 16.05:1 on [canvasLight].
  static const ink = Color(0xFF14213A);

  /// 5.41:1 on [canvasLight] — the smallest secondary text that still passes.
  static const inkMuted = Color(0xFF5B6B84);

  /// 2.65:1 on [canvasLight]. Decorative only: dividers, disabled glyphs,
  /// placeholder art. Never a label the user has to read.
  static const inkFaint = Color(0xFF93A0B5);

  static const inkOnDark = Color(0xFFE8EDF3);
  static const inkMutedOnDark = Color(0xFF93A0B5);
  static const inkFaintOnDark = Color(0xFF5B6B84);

  // ── Accent ramp: ink = text/icon, bright = fill/bar/dark-mode text ───────
  /// 5.55:1 on [canvasLight].
  static const accentInk = Color(0xFF0E6F9E);
  static const accentBright = Color(0xFF4DA8DA);

  /// 5.06:1 on [canvasLight].
  static const positiveInk = Color(0xFF157F45);
  static const positiveBright = Color(0xFF2ECC71);

  /// The brand amber, in both themes and in every role. 8.44:1 as text on the
  /// dark canvas; on the light one it is a fill, never a glyph — see the note
  /// above.
  static const caution = Color(0xFFF39C12);

  /// 6.54:1 on [canvasLight].
  static const criticalInk = Color(0xFFB3261E);
  static const criticalBright = Color(0xFFE74C3C);

  // ── Loading skeletons ───────────────────────────────────────────────────
  // A skeleton has to be visible against the canvas it sits on, which the
  // surface ramp is not: `surfaceSunkenLight` (#F7F8FA) on `canvasLight`
  // (#FFFFFF) is a 1.03:1 difference — the shimmer was there and nobody could
  // see it. These are a step further from the canvas, with a sheen that moves
  // *towards* it on light and away from it on dark.
  static const skeletonLight = Color(0xFFE9EDF2);
  static const skeletonSheenLight = Color(0xFFF6F8FA);
  static const skeletonBarLight = Color(0xFFD7DEE7);
  static const skeletonDark = Color(0xFF17273B);
  static const skeletonSheenDark = Color(0xFF20344E);
  static const skeletonBarDark = Color(0xFF2B3F5B);

  // ── Brand ───────────────────────────────────────────────────────────────
  /// The identity navy. Still used for the nav pill, map overlays and the
  /// photo-header scrim — surfaces that are dark in both themes.
  static const navy = Color(0xFF1B2A4A);
  static const navyDeep = Color(0xFF0A1628);

  /// White text on an accent-filled surface (primary button, FAB).
  static const onAccent = Color(0xFFFFFFFF);

  /// Text on a *light* fill — the amber and green status chips. Navy rather
  /// than white, because white on amber is 1.9:1 and unreadable.
  static const onLightFill = ink;

  // ── The one gradient that survives ──────────────────────────────────────
  /// Primary action fill (FAB, primary button). Every other gradient in the
  /// old palette was decorative and is gone: on a white canvas a gradient
  /// reads as a smudge, and it made every contrast check ambiguous.
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E6F9E), Color(0xFF1690C4)],
  );

  /// Same role, on the dark canvas, where the bright end is legible.
  static const accentGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A8FBF), Color(0xFF4DA8DA)],
  );

  /// The dark canvas keeps its depth gradient; the light one is flat on
  /// purpose (see `GradientBackground`).
  static const oceanDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1220), Color(0xFF0D1B2A)],
  );
}
