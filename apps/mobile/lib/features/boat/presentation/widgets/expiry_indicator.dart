import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';

class ExpiryIndicator extends StatelessWidget {
  const ExpiryIndicator({super.key, required this.expiryDate, this.size = 12});

  final DateTime expiryDate;
  final double size;

  Color get _color {
    if (NavisDateUtils.isExpired(expiryDate)) return AppColors.red;
    if (NavisDateUtils.isCritical(expiryDate)) return AppColors.red;
    if (NavisDateUtils.isWarning(expiryDate)) return AppColors.amber;
    return AppColors.green;
  }

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
        color: _color.withValues(alpha: 0.12),
        border: Border.all(
          color: _color.withValues(alpha: 0.25),
        ),
      ),
      child: Center(
        child: Icon(
          _icon,
          color: _color,
          size: iconSize,
        ),
      ),
    );

    if (_shouldPulse) {
      indicator = indicator
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.12, 1.12),
            duration: 800.ms,
            curve: Curves.easeInOut,
          )
          .then()
          .scale(
            begin: const Offset(1.12, 1.12),
            end: const Offset(1.0, 1.0),
            duration: 800.ms,
            curve: Curves.easeInOut,
          );
    }

    return indicator;
  }
}
