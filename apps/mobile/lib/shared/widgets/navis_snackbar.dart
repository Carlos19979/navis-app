import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class NavisSnackbar {
  NavisSnackbar._();

  static void success(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    _show(context, message, AppColors.green, Icons.check_circle_rounded);
  }

  static void error(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    _show(context, message, AppColors.red, Icons.error_rounded);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppColors.cyan, Icons.info_rounded);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, AppColors.amber, Icons.warning_rounded);
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color.withValues(alpha: 0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          duration: const Duration(seconds: 3),
          elevation: 0,
        ),
      );
  }
}
