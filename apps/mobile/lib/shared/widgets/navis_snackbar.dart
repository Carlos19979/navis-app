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
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
