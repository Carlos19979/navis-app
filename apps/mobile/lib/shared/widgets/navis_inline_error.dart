import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// A compact, single-row failure notice for a *section* of a screen.
///
/// Use this instead of [NavisErrorWidget] wherever the error has to fit inside
/// something else — a card, an expanded list row, a sheet. The full-page widget
/// is built around a 72 px icon and generous padding, so dropping it into a
/// short slot pushed its text out past the card it was drawn in. This one has
/// no intrinsic height to fight with: it wraps its text and keeps the retry
/// affordance on the same line.
class NavisInlineError extends StatelessWidget {
  const NavisInlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  /// A localized, human-readable reason. Never a raw exception string.
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spaceLg,
        vertical: Dimens.spaceMd,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: Dimens.iconSm,
            color: AppColors.amber,
          ),
          const SizedBox(width: Dimens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.txtSecondary,
                  ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.spaceSm,
                ),
                minimumSize: const Size(0, Dimens.minTouchTarget),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                l.retry,
                style: const TextStyle(color: AppColors.cyan),
              ),
            ),
        ],
      ),
    );
  }
}
