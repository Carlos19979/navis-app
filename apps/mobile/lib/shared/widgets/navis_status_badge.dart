import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';

/// The glass status pill for anything that expires. Documents and maintenance
/// tasks share it on purpose: an owner should not have to learn that "critical"
/// looks one way on an insurance policy and another on an oil change.
class NavisStatusBadge extends StatelessWidget {
  const NavisStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.glow = false,
  });

  final String label;
  final Color color;

  /// Adds the glow and a bounded shimmer — reserved for expired/critical.
  final bool glow;

  @override
  Widget build(BuildContext context) {
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
            boxShadow: glow
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

    if (glow) {
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
