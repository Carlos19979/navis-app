import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge({super.key, required this.expiryDate});

  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final Color color;
    final String label;

    if (NavisDateUtils.isExpired(expiryDate)) {
      color = AppColors.red;
      label = l.expired;
    } else if (NavisDateUtils.isCritical(expiryDate)) {
      color = AppColors.red;
      label = l.critical;
    } else if (NavisDateUtils.isWarning(expiryDate)) {
      color = AppColors.amber;
      label = l.warning;
    } else {
      color = AppColors.green;
      label = l.valid;
    }

    final shouldGlow = NavisDateUtils.isExpired(expiryDate) ||
        NavisDateUtils.isCritical(expiryDate);

    Widget badge = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
            ),
            boxShadow: shouldGlow
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );

    if (shouldGlow) {
      badge = badge
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shimmer(
            duration: 2000.ms,
            color: color.withValues(alpha: 0.15),
          );
    }

    return badge;
  }
}
