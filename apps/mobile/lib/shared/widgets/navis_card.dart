import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// A raised surface closed by a hairline.
///
/// Two things it deliberately does **not** do, both of which cost a pass per
/// card per frame — ten of them in a ten-row list, which is what showed up as
/// foreground battery drain:
///
///  * **No [BackdropFilter].** Blur gives back what is behind it, and behind a
///    card is a flat canvas (light) or a smooth gradient (dark). The effect was
///    invisible and it invalidated every layer beneath. Blur is kept only where
///    there is real detail behind it: map overlays, the in-trip dock, and the
///    app bar when it floats over media (see `GlassContainer`).
///  * **No drop shadow.** Depth comes from the hairline and from space. A soft
///    navy shadow under every card is also what gave the light theme its grey,
///    smudged look.
///
/// In the editorial layout most groupings want [NavisList] instead — a card is
/// for content that is genuinely a distinct object (a boat with its photo, a
/// modal panel), not for every group of rows.
class NavisCard extends StatelessWidget {
  const NavisCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.gradient,
    this.borderColor,
    this.sunken = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Overrides the surface fill. Still a gradient for callers that pass one,
  /// but the default is flat.
  final LinearGradient? gradient;

  final Color? borderColor;

  /// Recessed instead of raised — for a group that reads as part of the page
  /// rather than sitting on it.
  final bool sunken;

  @override
  Widget build(BuildContext context) {
    final fill = sunken ? context.surfaceSunken : context.surfaceRaised;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(Dimens.radiusSurface),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [fill, fill],
              ),
          borderRadius: BorderRadius.circular(Dimens.radiusSurface),
          border: Border.all(
            color: borderColor ?? context.hairline,
          ),
        ),
        child: Padding(
          padding: padding ?? Insets.card,
          child: child,
        ),
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}
