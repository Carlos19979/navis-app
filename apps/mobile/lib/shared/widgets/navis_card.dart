import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

/// The base card of the whole app: translucent gradient + hairline border.
///
/// It deliberately does NOT wrap its content in a [BackdropFilter]. Cards sit
/// on the app gradient background, and blurring a smooth gradient gives back
/// the same gradient — the effect was invisible while costing one blur pass
/// per card (a list of ten cards paid ten of them every frame, which on iOS is
/// among the most expensive things you can draw). Blur is kept only where
/// there is real detail behind it: the app bar, the bottom nav and the map
/// overlays.
class NavisCard extends StatelessWidget {
  const NavisCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget content = _buildGlassCard(isDark);

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }

  Widget _buildGlassCard(bool isDark) {
    final defaultBorder =
        isDark ? AppColors.glassBorder : AppColors.lightDivider;
    final defaultGradient = isDark
        ? AppColors.cardGradient
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xCCFFFFFF), Color(0x99FFFFFF)],
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient ?? defaultGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor ?? defaultBorder,
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
