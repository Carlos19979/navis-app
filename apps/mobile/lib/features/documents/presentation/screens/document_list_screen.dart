import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
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
    final l = AppLocalizations.of(context)!;
    final permissions = ref.watch(boatPermissionsProvider(boatId));
    // Reading the list is itself a permission — the API enforces
    // can_view_documents on GET — and both flags fail closed while unknown.
    final canView = permissions.grants(BoatPermissionArea.viewDocuments);
    final canManage = permissions.grants(BoatPermissionArea.manageDocuments);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: NavisAppBar(title: l.documents, showBack: true),
      body: GradientBackground(
        child: SafeArea(
          child: canView
              ? _DocumentList(boatId: boatId, canManage: canManage)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: BoatPermissionGate(
                    boatId: boatId,
                    area: BoatPermissionArea.viewDocuments,
                    placeholder:
                        const NavisShimmer(itemCount: 4, itemHeight: 80),
                    child: const SizedBox.shrink(),
                  ),
                ),
        ),
      ),
      // No add button without can_manage_documents; the list itself explains
      // why (see [_DocumentList]), so the padlock is not repeated here.
      floatingActionButton: canView && canManage
          ? NavisGradientFab(
              icon: Icons.add,
              onPressed: () => context.push(Routes.newDocument(boatId)),
              tooltip: l.newDocument,
            )
          : null,
    );
  }
}

class _DocumentList extends ConsumerWidget {
  const _DocumentList({required this.boatId, required this.canManage});

  final String boatId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final docsAsync = ref.watch(boatDocumentsProvider(boatId));

    return docsAsync.when(
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
            actionLabel: canManage ? l.newDocument : null,
            onAction: canManage
                ? () => context.push(Routes.newDocument(boatId))
                : null,
          );
        }

        final sorted = List<Document>.from(docs)
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

        return RefreshIndicator(
          color: context.accent,
          onRefresh: () async {
            ref.invalidate(boatDocumentsProvider(boatId));
            ref.invalidate(boatPermissionsProvider(boatId));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            // A read-only member gets the padlock and the reason at the top of
            // the list, not a silently missing button.
            itemCount: sorted.length + (canManage ? 0 : 1),
            itemBuilder: (context, index) {
              if (!canManage && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BlockedActionCard(
                    reason: permissionReason(
                      l,
                      BoatPermissionArea.manageDocuments,
                    ),
                    compact: true,
                  ),
                );
              }
              final doc = sorted[canManage ? index : index - 1];
              return DocumentCard(
                document: doc,
                onTap: () => context.push(Routes.document(doc.id)),
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
    );
  }
}
