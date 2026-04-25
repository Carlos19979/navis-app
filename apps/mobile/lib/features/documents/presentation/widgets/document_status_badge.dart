import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';

class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge({super.key, required this.expiryDate});

  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (NavisDateUtils.isExpired(expiryDate)) {
      color = AppColors.red;
      label = 'Expired';
    } else if (NavisDateUtils.isCritical(expiryDate)) {
      color = AppColors.red;
      label = 'Critical';
    } else if (NavisDateUtils.isWarning(expiryDate)) {
      color = AppColors.amber;
      label = 'Warning';
    } else {
      color = AppColors.green;
      label = 'Valid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
