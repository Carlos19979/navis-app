import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/network/storage_service.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/utils/money_utils.dart';
import 'package:navis_mobile/features/documents/presentation/document_type_label.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/boat/data/permission_errors.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat_permissions.dart';
import 'package:navis_mobile/features/boat/presentation/providers/boat_permissions_provider.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/permission_gate.dart';
import 'package:navis_mobile/features/documents/presentation/providers/document_provider.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
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
          // One word: with a back button and three actions the bar has ~150 px
          // for a title, so «Detalles del documento» truncated mid-word — and
          // the page's own heading already names the document.
          title: l.documentSingular,
          showBack: true,
          // Edit / renew / delete all need can_manage_documents on the
          // document's boat. The boat id only exists once the document has
          // loaded, so the actions resolve with it and stay hidden until then.
          actions: [
            if (docAsync.valueOrNull?.boatId case final boatId?)
              _DocumentActions(documentId: documentId, boatId: boatId),
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
                  // Was `doc.type` raw: the detail screen of «Seguro RC» was
                  // titled «insurance_rc».
                  : documentTypeLabel(l, doc.type);
              final locale = Localizations.localeOf(context).toLanguageTag();
              // Full alert-threshold list, falling back to the single legacy
              // value for rows cached before alert_days was carried through.
              final alertDays = doc.alertDays ??
                  [if (doc.alertDaysBefore != null) doc.alertDaysBefore!];
              return SingleChildScrollView(
                padding: Insets.screenWithNav,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The document, its status and how long is left. It used to
                    // be a card with a 4 px gradient stripe down its left edge
                    // and the days line tinted by state — amber text on the
                    // light canvas, which is brown.
                    // The chip goes *under* the title, on the same line as the
                    // days left. Beside it, a name like «Seguro de
                    // responsabilidad civil» wrapped to three lines with the
                    // chip floating in the gap — the two were reading as one
                    // broken block.
                    Text(
                      title,
                      style: NavisType.title1.copyWith(color: context.ink),
                    ),
                    const SizedBox(height: Dimens.spaceSm),
                    Row(
                      children: [
                        DocumentStatusBadge(expiryDate: doc.expiryDate),
                        const SizedBox(width: Dimens.spaceMd),
                        Expanded(
                          child: Text(
                            daysLeft < 0
                                ? l.daysOverdue(-daysLeft)
                                : l.daysRemaining(daysLeft),
                            style: NavisType.bodySm.copyWith(
                              color: context.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimens.spaceXl),
                    NavisList(
                      title: l.details,
                      padding: EdgeInsets.zero,
                      children: [
                        NavisRow(
                          title: l.expiryDate,
                          value: NavisDateUtils.formatDate(doc.expiryDate),
                        ),
                        if (alertDays.isNotEmpty)
                          NavisRow(
                            title: l.alert,
                            subtitle: '${alertDays.join(", ")} '
                                '${l.daysBeforeExpiry}',
                          ),
                        if (doc.notes != null && doc.notes!.isNotEmpty)
                          NavisRow(
                            title: l.notes,
                            subtitle: doc.notes,
                          ),
                      ],
                    ),
                    if (doc.lastRenewalDate != null) ...[
                      const SizedBox(height: Dimens.spaceXl),
                      NavisList(
                        title: l.lastRenewal,
                        padding: EdgeInsets.zero,
                        children: [
                          NavisRow(
                            title: l.date,
                            value: NavisDateUtils.formatDate(
                              doc.lastRenewalDate!,
                            ),
                          ),
                          if (doc.lastRenewalCost != null)
                            NavisRow(
                              title: l.cost,
                              // Through Money: this printed «€120.00» with the
                              // symbol glued in front and a decimal point in
                              // every language.
                              // Precise: this is one invoice, and its cents
                              // are part of what was paid — unlike a period
                              // total, which rounds.
                              value: Money.formatPrecise(
                                locale,
                                doc.lastRenewalCost!,
                              ),
                            ),
                          if (doc.lastRenewalProvider != null)
                            NavisRow(
                              title: l.provider,
                              subtitle: doc.lastRenewalProvider,
                            ),
                        ],
                      ),
                    ],
                    // Document scan image. The bucket is private: the stored
                    // URL is a stable identifier that gets exchanged for a
                    // short-lived signed URL at display time.
                    if (doc.photoUrl != null) ...[
                      const SizedBox(height: Dimens.spaceXl),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimens.radiusSurface,
                        ),
                        child: Semantics(
                          label: l.documentScan,
                          child: switch (ref.watch(
                              signedDocumentUrlProvider(doc.photoUrl!))) {
                            AsyncData(:final value) when value != null =>
                              CachedNetworkImage(
                                imageUrl: value,
                                memCacheWidth: 1200,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const _ScanPlaceholder(),
                                errorWidget: (context, url, error) =>
                                    const _ScanPlaceholder(broken: true),
                              ),
                            AsyncLoading() => const _ScanPlaceholder(),
                            _ => const _ScanPlaceholder(broken: true),
                          },
                        ),
                      ),
                    ],
                  ],
                ).entrance(),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Standing in for the scan while it loads, or when it will not.
class _ScanPlaceholder extends StatelessWidget {
  const _ScanPlaceholder({this.broken = false});

  final bool broken;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ColoredBox(
        color: context.surfaceSunken,
        child: Center(
          child: broken
              ? Icon(
                  Icons.broken_image_outlined,
                  size: Dimens.iconXl,
                  color: context.inkFaint,
                )
              : CircularProgressIndicator(
                  color: context.accent,
                  strokeWidth: 2,
                ),
        ),
      ),
    );
  }
}

/// Edit / renew / delete, shown only to someone who may manage the boat's
/// documents. A read-only member used to see all three and get a 403.
class _DocumentActions extends ConsumerWidget {
  const _DocumentActions({required this.documentId, required this.boatId});

  final String documentId;
  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final canManage = ref
        .watch(boatPermissionsProvider(boatId))
        .grants(BoatPermissionArea.manageDocuments);
    if (!canManage) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l.editDocument,
          onPressed: () => context.push(
            Routes.documentEdit(documentId, boatId: boatId),
          ),
        ),
        IconButton(
          icon: Icon(Icons.autorenew, color: context.accent),
          tooltip: l.renewDocument,
          onPressed: () => context.push(
            Routes.documentEdit(documentId, boatId: boatId, renew: true),
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outlined, color: context.critical),
          tooltip: l.delete,
          onPressed: () => _confirmDelete(context, ref, l),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await NavisConfirmDialog.show(
      context,
      title: l.deleteDocument,
      message: l.deleteDocumentConfirm,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(documentRepositoryProvider).deleteDocument(documentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.documentDeleted)),
        );
        context.pop();
      }
    } catch (e) {
      if (!context.mounted) return;
      // Safety net: revoked while the screen was open.
      if (isPermissionDeniedError(e)) {
        showPermissionDenied(
          context,
          ref,
          boatId: boatId,
          area: BoatPermissionArea.manageDocuments,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.failedToDelete)),
        );
      }
    }
  }
}
