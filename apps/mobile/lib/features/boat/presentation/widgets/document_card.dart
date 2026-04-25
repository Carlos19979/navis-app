import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/expiry_indicator.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final daysLeft = NavisDateUtils.daysUntil(document.expiryDate);

    return GestureDetector(
      onTap: () => context.go('/documents/${document.id}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ExpiryIndicator(expiryDate: document.expiryDate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.type,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NavisDateUtils.formatDate(document.expiryDate),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                daysLeft < 0
                    ? '${-daysLeft}d overdue'
                    : '${daysLeft}d left',
                style: TextStyle(
                  color: daysLeft < 0
                      ? AppColors.red
                      : daysLeft <= 7
                          ? AppColors.red
                          : daysLeft <= 30
                              ? AppColors.amber
                              : AppColors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
