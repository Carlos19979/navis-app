import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/palette.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// Paints the page canvas behind a screen.
///
/// Flat on light — a full-screen gradient on white reads as a smudge and made
/// every contrast check ambiguous — and the ocean gradient on dark, where it is
/// the identity. A [ColoredBox] on the light path so the common case is the
/// cheapest thing to draw.
class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.gradient,
  });

  final Widget child;

  /// Overrides the canvas. Used by the screens that own their own artwork.
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    if (gradient != null) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: child,
      );
    }
    if (!context.isDarkMode) {
      return ColoredBox(color: context.canvas, child: child);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Palette.oceanDark),
      child: child,
    );
  }
}

/// A translucent, blurred panel — for overlays that float on a **map or a
/// photograph**, which is the only place a backdrop filter earns its cost.
///
/// Not for cards, not for list rows, not for the app bar: over a flat canvas or
/// a smooth gradient a blur returns the same pixels it was given, and it
/// invalidates whatever repaints beneath it. See the doc comment on `NavisCard`.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = Dimens.radiusSurface,
    this.padding,
    this.margin,
    this.blur = Dimens.blurOverlay,
    this.opacity = 0.62,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            // Navy in both themes: this panel sits on imagery, not on the
            // page canvas, so it does not follow the surface ramp.
            color: Palette.navy.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Palette.hairlineDark,
            ),
          ),
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
