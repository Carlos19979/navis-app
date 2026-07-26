import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';

class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge({super.key, required this.expiryDate});

  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = NavisDateUtils.statusFor(expiryDate);
    final (Color color, String label) = switch (status) {
      DocExpiryStatus.expired => (AppColors.red, l.expired),
      DocExpiryStatus.critical => (AppColors.red, l.critical),
      DocExpiryStatus.warning => (AppColors.amber, l.warning),
      DocExpiryStatus.ok => (AppColors.green, l.valid),
    };

    final shouldGlow =
        status == DocExpiryStatus.expired || status == DocExpiryStatus.critical;

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
      // Bounded: an endless shimmer repaints this badge — and the blurred
      // layer it sits on — every frame for the whole life of the screen. The
      // red border and glow keep carrying the message once it stops.
      badge = RepaintBoundary(
        child: badge
            .animate(
              onPlay: (controller) =>
                  controller.repeat(count: PulseBudget.urgent),
            )
            .shimmer(
              duration: 2000.ms,
              color: color.withValues(alpha: 0.15),
            ),
      );
    }

    return badge;
  }
}
