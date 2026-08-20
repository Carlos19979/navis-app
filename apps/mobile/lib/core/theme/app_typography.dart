import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/palette.dart';

/// Nine type roles, mapped onto Material's fifteen slots.
///
/// The old scale had fifteen distinct styles and three near-duplicate pairs
/// (`headlineSmall`/`titleLarge` both 18pt, `titleMedium`/`bodyLarge` both
/// 16pt), which is why every screen picked a different one for the same job.
/// Nine roles, each with one job:
///
/// | role     | size/weight   | job                                        |
/// |----------|---------------|--------------------------------------------|
/// | display  | 34 / w700     | the one number that matters on the screen  |
/// | title1   | 26 / w700     | screen title                               |
/// | title2   | 20 / w600     | section heading                            |
/// | title3   | 17 / w600     | row title                                  |
/// | body     | 16 / w400     | running text                               |
/// | bodySm   | 14 / w400     | secondary text                             |
/// | label    | 13 / w600     | row label, button                          |
/// | caption  | 12 / w500     | metadata                                   |
/// | overline | 11 / w700     | list heading (uppercase, tracked)          |
///
/// Numerals are **tabular** in [display], [title1] and [caption]: those are the
/// styles that carry live figures (readiness score, total cost, distance,
/// temperature), and proportional digits made them jitter on every update.
abstract final class NavisType {
  /// Bundled Inter (variable weight axis) — no runtime font fetch.
  static const family = 'Inter';

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: family,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.1,
    fontFeatures: _tabular,
  );

  static const title1 = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    fontFeatures: _tabular,
  );

  static const title2 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const title3 = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const bodySm = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.35,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    fontFeatures: _tabular,
  );

  static const overline = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.3,
  );
}

/// Builds the Material [TextTheme] from [NavisType].
///
/// Every Material slot is filled, because ~130 call sites read them
/// (`textTheme.bodySmall` alone is used 35 times). The mapping collapses the
/// old near-duplicates onto one role each, so two screens that picked
/// different slots for the same job now render identically.
abstract final class AppTypography {
  static TextTheme get darkTextTheme => _theme(
        primary: Palette.inkOnDark,
        muted: Palette.inkMutedOnDark,
      );

  static TextTheme get lightTextTheme => _theme(
        primary: Palette.ink,
        muted: Palette.inkMuted,
      );

  static TextTheme _theme({
    required Color primary,
    required Color muted,
  }) {
    return TextTheme(
      // display
      displayLarge: NavisType.display.copyWith(color: primary),
      displayMedium: NavisType.display.copyWith(fontSize: 28, color: primary),
      displaySmall: NavisType.title1.copyWith(color: primary),
      // title1 / title2
      headlineLarge: NavisType.title1.copyWith(color: primary),
      headlineMedium: NavisType.title2.copyWith(color: primary),
      headlineSmall: NavisType.title2.copyWith(color: primary),
      // title3
      titleLarge: NavisType.title3.copyWith(color: primary),
      titleMedium: NavisType.title3.copyWith(color: primary),
      titleSmall: NavisType.label.copyWith(color: primary),
      // body
      bodyLarge: NavisType.body.copyWith(color: primary),
      bodyMedium: NavisType.bodySm.copyWith(color: primary),
      bodySmall: NavisType.caption.copyWith(color: muted),
      // label
      labelLarge: NavisType.label.copyWith(color: primary),
      labelMedium: NavisType.caption.copyWith(color: muted),
      labelSmall: NavisType.caption.copyWith(fontSize: 11, color: muted),
    );
  }
}
