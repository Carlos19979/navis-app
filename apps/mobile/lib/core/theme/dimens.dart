import 'package:flutter/widgets.dart';

/// Design tokens: the single source for spacing, radii, blur, icon sizes and
/// layout constants.
///
/// Spacing is a strict 8-grid (with a 4 half-step). Radii are down to **four**
/// values from six — the old scale had 8/12/14/16/20 plus 117 loose
/// `BorderRadius.circular(N)` literals, which is why no two cards in the app
/// had the same corner.
abstract final class Dimens {
  // ── Spacing: 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 ────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;
  static const double space3xl = 48;
  static const double space4xl = 64;

  // ── Radii: four values, named after what they wrap ───────────────────────
  /// Chips, badges, status pills that are not fully round.
  static const double radiusChip = 10;

  /// Inputs, buttons, snackbars — anything you tap or type into.
  static const double radiusControl = 14;

  /// Cards, sheets, dialogs, menus.
  static const double radiusSurface = 20;

  static const double radiusPill = 999;

  // Legacy radius names, remapped onto the four above. Used by ~24 call sites
  // that are migrating; do not add new uses.
  static const double radiusSm = radiusChip;
  static const double radiusMd = radiusControl;
  static const double radiusLg = radiusControl;
  static const double radiusXl = radiusSurface;
  static const double radiusXxl = radiusSurface;

  // ── Backdrop blur ───────────────────────────────────────────────────────
  // Blur is a per-frame GPU cost that also invalidates whatever sits under it,
  // so there is deliberately **no `blurCard`**: cards must never blur (see the
  // doc comment on NavisCard). These are the only four places that may.

  /// Overlays floating on the map — banners, control clusters.
  static const double blurOverlay = 10;

  /// The in-trip control dock.
  static const double blurControls = 12;

  /// The app bar, which has content scrolling under it.
  static const double blurAppBar = 20;

  /// The floating bottom-nav pill.
  static const double blurNav = 25;

  // ── Icons ───────────────────────────────────────────────────────────────
  /// Inline with text (chips, metadata rows).
  static const double iconSm = 18;

  /// Standard action icon.
  static const double iconMd = 20;

  /// Leading icon of a row, nav-bar icon.
  static const double iconLg = 24;

  /// Empty-state and placeholder art.
  static const double iconXl = 40;

  /// Minimum interactive target (Material/WCAG guidance).
  static const double minTouchTarget = 48;

  /// Height of the floating bottom navigation pill.
  static const double bottomNavHeight = 68;

  /// Bottom padding a scrollable screen must leave so its last item clears the
  /// floating bottom nav. Use instead of the ad-hoc 100/112/130 constants.
  ///
  /// Sized for the worst case: the pill height ([bottomNavHeight] = 68) plus the
  /// pill's own bottom offset above the home indicator (safe-area inset ~34 on
  /// notched phones, minus the ~10 the nav eats back) plus breathing room, so
  /// the last item clears the pill on home-indicator devices, not just those
  /// with a hardware button.
  static const double navClearance = 120;

  /// Width of a row's trailing value column.
  ///
  /// Fixed on purpose. It used to be a `Flexible` sharing its flex with the
  /// title's `Expanded`, so the two split the free space 50/50 and every value
  /// right-aligned inside a box of a different width — «sin registrar» ended at
  /// x=374 and «en 90 d» at x=313 in *adjacent rows*. A list only reads as a
  /// column if the column is one.
  static const double rowValueColumn = 96;

  /// Hairline thickness. One physical-ish line, not the 0.5 that disappeared
  /// on some densities.
  static const double hairline = 1;

  /// Longest comfortable measure for running text, so body copy does not run
  /// edge to edge on a tablet.
  static const double maxTextWidth = 560;
}

/// Common EdgeInsets built from the spacing scale, to avoid re-declaring the
/// same paddings inline across screens.
abstract final class Insets {
  static const EdgeInsets screen = EdgeInsets.all(Dimens.spaceLg);
  static const EdgeInsets card = EdgeInsets.all(Dimens.spaceLg);

  /// Horizontal page gutter, for a list whose rows draw their own separators
  /// edge to edge.
  static const EdgeInsets gutter =
      EdgeInsets.symmetric(horizontal: Dimens.spaceLg);

  /// Screen padding that also clears the bottom nav (for scroll views).
  static const EdgeInsets screenWithNav = EdgeInsets.fromLTRB(
    Dimens.spaceLg,
    Dimens.spaceLg,
    Dimens.spaceLg,
    Dimens.navClearance,
  );

  /// Gutter-only padding that clears the bottom nav, for edge-to-edge lists.
  static const EdgeInsets gutterWithNav = EdgeInsets.fromLTRB(
    Dimens.spaceLg,
    0,
    Dimens.spaceLg,
    Dimens.navClearance,
  );
}
