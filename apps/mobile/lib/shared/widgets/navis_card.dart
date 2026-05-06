import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class NavisCard extends StatelessWidget {
  const NavisCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.blur = true,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool blur;
  final LinearGradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget content = blur ? _buildGlassCard(isDark) : _buildSolidCard(isDark);

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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
      ),
    );
  }

  Widget _buildSolidCard(bool isDark) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final defaultBorder =
        isDark ? AppColors.glassBorder : AppColors.lightDivider;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? defaultBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
