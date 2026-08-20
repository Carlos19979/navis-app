import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// How loudly an alert speaks.
enum NavisAlertTone { critical, caution, info }

/// A tinted banner stating one thing that went wrong, or one thing to know.
///
/// Extracted from the two identical 30-line blocks in the login and register
/// screens, which wrapped a `BackdropFilter` around a 6%-opacity fill — a blur
/// pass for a veil nobody could see through. Flat tint, hairline border, no
/// blur.
///
/// This is for a message the user reads and moves on from. When the failure has
/// a retry, use `NavisInlineError`; when it takes the whole screen, use
/// `NavisErrorWidget`.
class NavisAlert extends StatelessWidget {
  const NavisAlert({
    super.key,
    required this.message,
    this.tone = NavisAlertTone.critical,
    this.icon,
    this.margin,
  });

  /// Localized and human-readable. Never a raw exception string.
  final String message;
  final NavisAlertTone tone;
  final IconData? icon;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      NavisAlertTone.critical => context.critical,
      NavisAlertTone.caution => context.caution,
      NavisAlertTone.info => context.accent,
    };
    final glyph = icon ??
        switch (tone) {
          NavisAlertTone.critical => Icons.error_outline_rounded,
          NavisAlertTone.caution => Icons.warning_amber_rounded,
          NavisAlertTone.info => Icons.info_outline_rounded,
        };

    final banner = DecoratedBox(
      decoration: BoxDecoration(
        color: context.wash(color),
        borderRadius: BorderRadius.circular(Dimens.radiusControl),
        border: Border.all(color: context.washBorder(color)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spaceMd),
        child: Row(
          children: [
            Icon(glyph, color: color, size: Dimens.iconMd),
            const SizedBox(width: Dimens.spaceMd),
            Expanded(
              child: Text(
                message,
                style: NavisType.bodySm.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      liveRegion: true,
      child: margin == null ? banner : Padding(padding: margin!, child: banner),
    );
  }
}
