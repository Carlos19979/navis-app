import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

class DocumentListScreen extends ConsumerWidget {
  const DocumentListScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(boatDocumentsProvider(boatId));
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: NavisAppBar(title: l.documents, showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: docsAsync.when(
            loading: () => const NavisShimmer(itemCount: 4, itemHeight: 80),
            error: (error, stack) => NavisErrorWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(boatDocumentsProvider(boatId)),
            ),
            data: (docs) {
              if (docs.isEmpty) {
                return NavisEmptyState(
                  icon: Icons.description_outlined,
                  message: l.noDocuments,
                  actionLabel: l.newDocument,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final doc = sorted[index];
                    return _DocumentCard(doc: doc)
                        .animate()
                        .fadeIn(
                          duration: 400.ms,
                          delay: (50 * index).ms,
                        )
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 400.ms,
                          delay: (50 * index).ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: (ref
                  .watch(boatProvider(boatId))
                  .valueOrNull
                  ?.permissions
                  .canManageDocuments ??
              true)
          ? Container(
              decoration: BoxDecoration(
                gradient: AppColors.cyanGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => context.push('/boats/$boatId/documents/new'),
                tooltip: l.newDocument,
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  semanticLabel: l.newDocument,
                ),
              ),
            )
          : null,
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
    final (statusColor, _) = switch (daysUntilExpiry) {
      < 0 => (AppColors.red, 'Expired'),
      <= 30 => (AppColors.red, 'Critical'),
      <= 90 => (AppColors.amber, 'Warning'),
      _ => (AppColors.green, 'OK'),
    };

    return NavisCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      onTap: () => context.push('/documents/${doc.id}'),
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
                    statusColor,
                    statusColor.withValues(alpha: 0.4),
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
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.txtSecondary,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    DocumentStatusBadge(expiryDate: doc.expiryDate),
                  ],
                ),
              ),
            ),
          ],
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
