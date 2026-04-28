import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class DocumentListScreen extends ConsumerWidget {
  const DocumentListScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(boatDocumentsProvider(boatId));

    return Scaffold(
      appBar: const NavisAppBar(title: 'Documents', showBack: true),
      body: docsAsync.when(
        loading: () => const NavisShimmer(itemCount: 4, itemHeight: 80),
        error: (error, stack) => NavisErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(boatDocumentsProvider(boatId)),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return NavisEmptyState(
              icon: Icons.description_outlined,
              message: 'No documents yet. Add your first document!',
              actionLabel: 'Add Document',
              onAction: () => context.push('/boats/$boatId/documents/new'),
            );
          }

          final sorted = List<Document>.from(docs)
            ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

          return RefreshIndicator(
            color: AppColors.cyan,
            onRefresh: () async {
              ref.invalidate(boatDocumentsProvider(boatId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final doc = sorted[index];
                return _DocumentCard(doc: doc);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/boats/$boatId/documents/new'),
        tooltip: 'Add document',
        child: const Icon(Icons.add, semanticLabel: 'Add document'),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.doc});

  final Document doc;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysUntilExpiry = doc.expiryDate.difference(now).inDays;
    final (statusColor, statusLabel) = switch (daysUntilExpiry) {
      < 0 => (AppColors.red, 'Expired'),
      <= 30 => (AppColors.red, 'Critical'),
      <= 90 => (AppColors.amber, 'Warning'),
      _ => (AppColors.green, 'OK'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/documents/${doc.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatType(doc.type),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires: ${_formatDate(doc.expiryDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
