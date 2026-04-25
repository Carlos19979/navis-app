import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(documentProvider(documentId));

    return Scaffold(
      appBar: const NavisAppBar(title: 'Document Details', showBack: true),
      body: docAsync.when(
        loading: () => const NavisLoading(),
        error: (error, stack) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(documentProvider(documentId)),
        ),
        data: (doc) {
          final daysLeft = NavisDateUtils.daysUntil(doc.expiryDate);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                doc.type,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                            ),
                            DocumentStatusBadge(expiryDate: doc.expiryDate),
                          ],
                        ),
                        const Divider(height: 32),
                        _DetailRow(
                          label: 'Expiry Date',
                          value: NavisDateUtils.formatDate(doc.expiryDate),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Status',
                          value: daysLeft < 0
                              ? '${-daysLeft} days overdue'
                              : '$daysLeft days remaining',
                        ),
                        if (doc.alertDaysBefore != null) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            label: 'Alert',
                            value: '${doc.alertDaysBefore} days before expiry',
                          ),
                        ],
                        if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(label: 'Notes', value: doc.notes!),
                        ],
                      ],
                    ),
                  ),
                ),
                if (doc.photoUrl != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        color: AppColors.darkCard,
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
