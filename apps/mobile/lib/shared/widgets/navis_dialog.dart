import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// Shared confirmation and text-input dialogs, replacing the ~15 hand-rolled
/// AlertDialogs copied across screens. Both use the app's dialog surface and
/// text colors and default their buttons to the app localizations.
class NavisConfirmDialog {
  const NavisConfirmDialog._();

  /// Shows a confirm/cancel dialog. Returns true only when confirmed.
  /// [destructive] paints the confirm action red (delete/leave flows).
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
  }) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.dialogSurface,
        title: Text(title, style: TextStyle(color: ctx.txtPrimary)),
        content: Text(message, style: TextStyle(color: ctx.txtSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel ?? l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.red)
                : null,
            child: Text(confirmLabel ?? l.confirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class NavisInputDialog {
  const NavisInputDialog._();

  /// Shows a single-text-field dialog. Returns the trimmed text, or null if
  /// cancelled or left empty.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hintText,
    String? confirmLabel,
    String? cancelLabel,
    bool uppercase = false,
  }) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.dialogSurface,
        title: Text(title, style: TextStyle(color: ctx.txtPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: uppercase
              ? TextCapitalization.characters
              : TextCapitalization.none,
          style: TextStyle(color: ctx.txtPrimary),
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelLabel ?? l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(confirmLabel ?? l.confirm),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return null;
    return result;
  }
}
