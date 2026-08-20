import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';
import 'package:navis_mobile/shared/utils/status_colors.dart';

class ExpiryIndicator extends StatelessWidget {
  const ExpiryIndicator({super.key, required this.expiryDate, this.size = 12});

  final DateTime expiryDate;
  final double size;

  Color _color(BuildContext context) => context.expiryColor(expiryDate);

  IconData get _icon {
    if (NavisDateUtils.isExpired(expiryDate)) return Icons.error;
    if (NavisDateUtils.isCritical(expiryDate)) return Icons.warning;
    if (NavisDateUtils.isWarning(expiryDate)) return Icons.info;
    return Icons.check_circle;
  }

  bool get _shouldPulse =>
      NavisDateUtils.isExpired(expiryDate) ||
      NavisDateUtils.isCritical(expiryDate);

  @override
  Widget build(BuildContext context) {
    final iconSize = size + 8;
    final containerSize = iconSize + 12;

    Widget indicator = Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color(context).withValues(alpha: 0.12),
        border: Border.all(
          color: _color(context).withValues(alpha: 0.25),
        ),
      ),
      child: Center(
        child: Icon(
          _icon,
          color: _color(context),
          size: iconSize,
        ),
      ),
    );

    if (_shouldPulse) {
      // Expiry is worth a pulse, but a bounded one: `repeat()` with no count
      // repaints at 60 fps for as long as the screen is open and invalidates
      // the layers underneath on every frame. A few there-and-back cycles say
      // the same thing, and the red icon stays after they end.
      indicator = RepaintBoundary(
        child: indicator
            .animate(
              onPlay: (controller) => controller.repeat(
                reverse: true,
                count: PulseBudget.reverseHalves(PulseBudget.urgent),
              ),
            )
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.12, 1.12),
              duration: 800.ms,
              curve: Curves.easeInOut,
            ),
      );
    }

    return indicator;
  }
}
