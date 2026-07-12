import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/expiry_indicator.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.document, this.onTap});

  final Document document;

  /// Tap handler. Defaults to `context.go` to the document detail; the
  /// documents list passes `context.push` so back returns to the list.
  final VoidCallback? onTap;

  Color get _statusColor {
    final daysLeft = NavisDateUtils.daysUntil(document.expiryDate);
    if (daysLeft < 0) return AppColors.red;
    if (daysLeft <= 30) return AppColors.red;
    if (daysLeft <= 90) return AppColors.amber;
    return AppColors.green;
  }

  /// Prettifies a stored document type for display: snake_case → Title Case
  /// (e.g. `safety_certificate` → `Safety Certificate`). Already-nice values
  /// (e.g. `Insurance`) pass through unchanged.
  static String _prettyType(String type) => type
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      onTap: onTap ?? () => context.go('/documents/${document.id}'),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _statusColor,
                    _statusColor.withValues(alpha: 0.4),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    ExpiryIndicator(expiryDate: document.expiryDate),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _prettyType(document.type),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            NavisDateUtils.formatDate(document.expiryDate),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.txtSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    DocumentStatusBadge(expiryDate: document.expiryDate),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
