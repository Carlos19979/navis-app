import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

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
      appBar: NavisAppBar(
        title: 'Document Details',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit document',
            onPressed: () {
              final doc = ref.read(documentProvider(documentId)).valueOrNull;
              if (doc != null) {
                context.push(
                  '/documents/$documentId/edit?boatId=${doc.boatId}',
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.autorenew, color: AppColors.cyan),
            tooltip: 'Renew document',
            onPressed: () {
              final doc = ref.read(documentProvider(documentId)).valueOrNull;
              if (doc != null) {
                context.push(
                  '/documents/$documentId/edit?boatId=${doc.boatId}&renew=true',
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outlined, color: AppColors.red),
            tooltip: 'Delete document',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
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
                                style:
                                    Theme.of(context).textTheme.headlineMedium,
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
                        if (doc.lastRenewalDate != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 24),
                          Text(
                            'Last Renewal',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            label: 'Date',
                            value: NavisDateUtils.formatDate(
                              doc.lastRenewalDate!,
                            ),
                          ),
                          if (doc.lastRenewalCost != null) ...[
                            const SizedBox(height: 8),
                            _DetailRow(
                              label: 'Cost',
                              value:
                                  '\u20AC${doc.lastRenewalCost!.toStringAsFixed(2)}',
                            ),
                          ],
                          if (doc.lastRenewalProvider != null) ...[
                            const SizedBox(height: 8),
                            _DetailRow(
                              label: 'Provider',
                              value: doc.lastRenewalProvider!,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                if (doc.photoUrl != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Semantics(
                      label: 'Document scan',
                      child: CachedNetworkImage(
                        imageUrl: doc.photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.cyan,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to delete this document?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(documentRepositoryProvider);
                await repo.deleteDocument(documentId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document deleted')),
                  );
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
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
