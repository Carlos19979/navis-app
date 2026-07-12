import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_provider.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/document_card.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
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
                    return DocumentCard(
                      document: doc,
                      onTap: () => context.push('/documents/${doc.id}'),
                    )
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
          ? NavisGradientFab(
              icon: Icons.add,
              onPressed: () => context.push('/boats/$boatId/documents/new'),
              tooltip: l.newDocument,
            )
          : null,
    );
  }
}
