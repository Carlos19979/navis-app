import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_loading.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final docAsync = ref.watch(documentProvider(documentId));

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(
          title: l.documentDetails,
          showBack: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l.editDocument,
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
              tooltip: l.renewDocument,
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
              tooltip: l.delete,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        body: SafeArea(
          child: docAsync.when(
            loading: () => const NavisLoading(),
            error: (error, stack) => NavisErrorWidget(
              message: error.toString(),
              onRetry: () => ref.invalidate(documentProvider(documentId)),
            ),
            data: (doc) {
              final daysLeft = NavisDateUtils.daysUntil(doc.expiryDate);
              // Custom documents show their user-given name as the title.
              final customName = doc.customName;
              final title = doc.type == 'custom' &&
                      customName != null &&
                      customName.isNotEmpty
                  ? customName
                  : doc.type;
              // Full alert-threshold list, falling back to the single legacy
              // value for rows cached before alert_days was carried through.
              final alertDays = doc.alertDays ??
                  [if (doc.alertDaysBefore != null) doc.alertDaysBefore!];
              final statusColor = daysLeft < 0
                  ? AppColors.red
                  : daysLeft <= 30
                      ? AppColors.red
                      : daysLeft <= 90
                          ? AppColors.amber
                          : AppColors.green;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card with status accent
                    NavisCard(
                      padding: EdgeInsets.zero,
                      borderColor: statusColor.withValues(alpha: 0.3),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Container(
                              width: 4,
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
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        DocumentStatusBadge(
                                            expiryDate: doc.expiryDate),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      daysLeft < 0
                                          ? l.daysOverdue(-daysLeft)
                                          : l.daysRemaining(daysLeft),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(
                          begin: 0.05,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    const SizedBox(height: 16),

                    // Details card
                    NavisCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.details,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.cyan,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.calendar_today_outlined,
                            label: l.expiryDate,
                            value: NavisDateUtils.formatDate(doc.expiryDate),
                          ),
                          if (alertDays.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _DetailRow(
                              icon: Icons.notifications_outlined,
                              label: l.alert,
                              value: '${alertDays.join(", ")} '
                                  '${l.daysBeforeExpiry}',
                            ),
                          ],
                          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _DetailRow(
                              icon: Icons.notes_outlined,
                              label: l.notes,
                              value: doc.notes!,
                            ),
                          ],
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 400.ms,
                          delay: 100.ms,
                        )
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          duration: 400.ms,
                          delay: 100.ms,
                          curve: Curves.easeOutCubic,
                        ),

                    // Renewal info card
                    if (doc.lastRenewalDate != null) ...[
                      const SizedBox(height: 16),
                      NavisCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.lastRenewal,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.cyan,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _DetailRow(
                              icon: Icons.event_outlined,
                              label: l.date,
                              value: NavisDateUtils.formatDate(
                                doc.lastRenewalDate!,
                              ),
                            ),
                            if (doc.lastRenewalCost != null) ...[
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.euro_outlined,
                                label: l.cost,
                                value:
                                    '\u20AC${doc.lastRenewalCost!.toStringAsFixed(2)}',
                              ),
                            ],
                            if (doc.lastRenewalProvider != null) ...[
                              const SizedBox(height: 12),
                              _DetailRow(
                                icon: Icons.business_outlined,
                                label: l.provider,
                                value: doc.lastRenewalProvider!,
                              ),
                            ],
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 400.ms,
                            delay: 200.ms,
                          )
                          .slideY(
                            begin: 0.05,
                            end: 0,
                            duration: 400.ms,
                            delay: 200.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ],

                    // Document scan image. The bucket is private: the stored
                    // URL is a stable identifier that gets exchanged for a
                    // short-lived signed URL at display time.
                    if (doc.photoUrl != null) ...[
                      const SizedBox(height: 16),
                      NavisCard(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Semantics(
                            label: 'Document scan',
                            child: switch (ref.watch(
                                signedDocumentUrlProvider(doc.photoUrl!))) {
                              AsyncData(:final value) when value != null =>
                                CachedNetworkImage(
                                  imageUrl: value,
                                  memCacheWidth: 1200,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.cyan,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      AspectRatio(
                                    aspectRatio: 4 / 3,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: context.txtSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              AsyncLoading() => const AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.cyan,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              _ => AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                      color: context.txtSecondary,
                                    ),
                                  ),
                                ),
                            },
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 400.ms,
                            delay: 300.ms,
                          )
                          .slideY(
                            begin: 0.05,
                            end: 0,
                            duration: 400.ms,
                            delay: 300.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.deleteDocument,
      message: l.deleteDocumentConfirm,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final repo = ref.read(documentRepositoryProvider);
      await repo.deleteDocument(documentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.documentDeleted)),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.failedToDelete)),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: context.txtSecondary,
          ),
          const SizedBox(width: 10),
        ],
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.txtSecondary,
                ),
          ),
        ),
        const SizedBox(width: 8),
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
