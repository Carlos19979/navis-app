import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/palette.dart';

/// The colour API for the whole app. Screens read colours from here and never
/// from [Palette] or `AppColors`, because every colour has two values — one per
/// theme — and only a [BuildContext] knows which one applies.
///
/// **Accents come in two roles, and picking the wrong one is a legibility bug.**
/// The four brand accents were designed against the dark navy canvas; on white
/// they land between 2.10:1 and 3.82:1, well under WCAG AA. So:
///
///  * [accent] / [positive] / [caution] / [critical] — **text and icons**.
///    Resolve to the darkened `*Ink` value on light, the bright value on dark.
///    These are the default; reach for them unless you are filling a shape.
///  * [accentFill] / [positiveFill] / [cautionFill] / [criticalFill] —
///    **fills, bars, chart series, status dots**. Always the bright value: the
///    contrast that matters for a shape is against its neighbour, not a glyph.
///  * [wash] — the 12% tint behind an icon or chip. Takes either role and
///    flattens it to a background you can put [ink] text on.
extension ThemeColorsX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  // ── Surfaces ────────────────────────────────────────────────────────────

  /// The page background.
  Color get canvas => _dark ? Palette.canvasDark : Palette.canvasLight;

  /// A recessed area inside the page (grouped list, search field, code block).
  Color get surfaceSunken =>
      _dark ? Palette.surfaceSunkenDark : Palette.surfaceSunkenLight;

  /// A surface that sits above the canvas (card, sheet, menu).
  Color get surfaceRaised =>
      _dark ? Palette.surfaceRaisedDark : Palette.surfaceRaisedLight;

  /// The 1px separator that carries hierarchy in place of a shadow.
  Color get hairline => _dark ? Palette.hairlineDark : Palette.hairlineLight;

  // ── Ink ─────────────────────────────────────────────────────────────────

  /// Primary text and icons.
  Color get ink => _dark ? Palette.inkOnDark : Palette.ink;

  /// Secondary text: labels, metadata, captions. Still AA.
  Color get inkMuted => _dark ? Palette.inkMutedOnDark : Palette.inkMuted;

  /// Decorative only — placeholder art, disabled glyphs. Never a label the
  /// user has to read (2.65:1 on white).
  Color get inkFaint => _dark ? Palette.inkFaintOnDark : Palette.inkFaint;

  // ── Accents, text role ──────────────────────────────────────────────────

  Color get accent => _dark ? Palette.accentBright : Palette.accentInk;
  Color get positive => _dark ? Palette.positiveBright : Palette.positiveInk;
  Color get caution => _dark ? Palette.cautionBright : Palette.cautionInk;
  Color get critical => _dark ? Palette.criticalBright : Palette.criticalInk;

  // ── Accents, fill role ──────────────────────────────────────────────────

  Color get accentFill => Palette.accentBright;
  Color get positiveFill => Palette.positiveBright;
  Color get cautionFill => Palette.cautionBright;
  Color get criticalFill => Palette.criticalBright;

  /// Text/icon colour that sits on top of an accent-filled surface.
  Color get onAccent => Palette.onAccent;

  /// The primary-action gradient (FAB, primary button).
  LinearGradient get accentGradient =>
      _dark ? Palette.accentGradientDark : Palette.accentGradient;

  /// Base fill of a loading skeleton.
  Color get skeleton => _dark ? Palette.skeletonDark : Palette.skeletonLight;

  /// The travelling highlight of a loading skeleton.
  Color get skeletonSheen =>
      _dark ? Palette.skeletonSheenDark : Palette.skeletonSheenLight;

  /// The placeholder bars inside a skeleton row. A step *further* from the
  /// canvas than [skeleton], so they read as stand-in content rather than
  /// dissolving into the row they sit on.
  Color get skeletonBar =>
      _dark ? Palette.skeletonBarDark : Palette.skeletonBarLight;

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// A tinted background derived from [color], for the circle behind an icon
  /// or the fill of a status chip. Stronger on dark, where a 12% veil over
  /// navy barely registers.
  Color wash(Color color) => color.withValues(alpha: _dark ? 0.18 : 0.10);

  /// The hairline-strength border derived from [color], for a chip that needs
  /// to read as outlined rather than filled.
  Color washBorder(Color color) => color.withValues(alpha: _dark ? 0.34 : 0.22);

  // ── Legacy names ────────────────────────────────────────────────────────
  // Kept because 501 call sites use them. They now resolve through the ramps
  // above, so they are correct in both themes; the names are being migrated
  // to the semantic ones (txtPrimary → ink, glassBg → surfaceSunken …) as
  // each screen is reworked. Do not add new uses.

  /// Migrating to [ink].
  Color get txtPrimary => ink;

  /// Migrating to [inkMuted].
  Color get txtSecondary => inkMuted;

  /// Migrating to [surfaceSunken].
  Color get glassBg => surfaceSunken;

  /// Migrating to [hairline].
  Color get glassBorderColor => hairline;

  /// Migrating to [surfaceRaised].
  Color get dialogSurface => surfaceRaised;

  /// Migrating to [surfaceRaised].
  Color get dialogSurfaceElevated => surfaceRaised;

  /// Migrating away entirely: a modal surface is a flat [surfaceRaised] now.
  LinearGradient get surfaceGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [surfaceRaised, surfaceRaised],
      );
}
