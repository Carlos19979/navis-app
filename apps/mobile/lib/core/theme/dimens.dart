import 'package:flutter/widgets.dart';

/// Design tokens: the single source for spacing, radii, blur, icon sizes and
/// layout constants. Replaces the scattered magic numbers (256 inline SizedBox
/// heights, 43 inline EdgeInsets, radii of 12/14/16/20 repeated by hand, and
/// the 100/112/130 bottom-nav clearances that varied per screen).
abstract final class Dimens {
  // Spacing scale.
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  // Corner radii (mirrors the de-facto scale already in use).
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 14; // buttons, inputs, snackbars
  static const double radiusXl = 16; // cards, glass surfaces
  static const double radiusXxl = 20; // dialogs, chips
  static const double radiusPill = 999;

  // Backdrop blur sigmas, named after where they're used.
  static const double blurCard = 10;
  static const double blurControls = 12;
  static const double blurAppBar = 20;
  static const double blurNav = 25;

  // Icon sizes.
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 40;

  /// Minimum interactive target (Material/WCAG guidance).
  static const double minTouchTarget = 48;

  /// Height of the floating bottom navigation pill.
  static const double bottomNavHeight = 68;

  /// Bottom padding a scrollable screen must leave so its last item clears the
  /// floating bottom nav. Use instead of the ad-hoc 100/112/130 constants.
  static const double navClearance = 112;
}

/// Common EdgeInsets built from the spacing scale, to avoid re-declaring the
/// same paddings inline across screens.
abstract final class Insets {
  static const EdgeInsets screen = EdgeInsets.all(Dimens.spaceLg);
  static const EdgeInsets card = EdgeInsets.all(Dimens.spaceLg);

  /// Screen padding that also clears the bottom nav (for scroll views).
  static const EdgeInsets screenWithNav = EdgeInsets.fromLTRB(
    Dimens.spaceLg,
    Dimens.spaceLg,
    Dimens.spaceLg,
    Dimens.navClearance,
  );
}
