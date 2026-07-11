import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

/// The cyan-gradient FloatingActionButton used across screens, replacing the
/// byte-identical gradient container + transparent FAB copied ~5 times.
class NavisGradientFab extends StatelessWidget {
  const NavisGradientFab({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.label,
    this.heroTag,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  /// When set, renders an extended (icon + label) FAB.
  final String? label;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cyanGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: label == null
          ? FloatingActionButton(
              heroTag: heroTag,
              onPressed: onPressed,
              tooltip: tooltip,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Icon(icon, color: Colors.white, semanticLabel: tooltip),
            )
          : FloatingActionButton.extended(
              heroTag: heroTag,
              onPressed: onPressed,
              tooltip: tooltip,
              elevation: 0,
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: Icon(icon, color: Colors.white),
              label: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}
