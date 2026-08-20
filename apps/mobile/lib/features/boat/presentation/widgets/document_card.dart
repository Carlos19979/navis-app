import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/presentation/document_type_label.dart';
import 'package:navis_mobile/features/documents/presentation/widgets/document_status_badge.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// One document in the list: what it is, when it runs out, and how worried to
/// be about that.
///
/// Editorial row rather than a card. It carried a card *plus* a 3 px gradient
/// severity stripe *plus* a tinted circular icon badge *plus* the status chip —
/// four devices saying the same thing, and the row that mattered (the expired
/// one) had no way left to stand out. The chip says it; the rest is type.
class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.document, this.onTap});

  final Document document;

  /// Tap handler. Defaults to `context.go` to the document detail; the
  /// documents list passes `context.push` so back returns to the list.
  final VoidCallback? onTap;

  /// The user's own name for a `custom` document, the localized type otherwise.
  String _title(AppLocalizations l) {
    final customName = document.customName;
    if (document.type == 'custom' &&
        customName != null &&
        customName.isNotEmpty) {
      return customName;
    }
    // Through the shared label: this used to title-case the raw type, so the
    // list said «Insurance Rc» about a document whose own form said «Seguro
    // RC».
    return documentTypeLabel(l, document.type);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = _title(l);

    return Semantics(
      button: true,
      label: title,
      value: NavisDateUtils.formatDate(document.expiryDate),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap ?? () => context.go(Routes.document(document.id)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.hairline)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimens.spaceLg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NavisType.title3.copyWith(color: context.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          NavisDateUtils.formatDate(document.expiryDate),
                          style: NavisType.caption.copyWith(
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Dimens.spaceMd),
                  DocumentStatusBadge(expiryDate: document.expiryDate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
