import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Icon(
      _icon,
      color: _color,
      size: size + 8,
    );
  }
}
