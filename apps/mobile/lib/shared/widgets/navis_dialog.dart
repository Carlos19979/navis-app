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
  ///
  /// [initialValue] pre-fills and selects the field, for editing an existing
  /// value rather than entering a new one.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? hintText,
    String? confirmLabel,
    String? cancelLabel,
    String? initialValue,
    bool uppercase = false,
    TextCapitalization capitalization = TextCapitalization.none,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _InputDialog(
        title: title,
        hintText: hintText,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        initialValue: initialValue,
        capitalization:
            uppercase ? TextCapitalization.characters : capitalization,
      ),
    );
    if (result == null || result.isEmpty) return null;
    return result;
  }
}

/// The dialog body, stateful purely so the [TextEditingController] has an owner
/// with a lifecycle. Disposing it after `showDialog` returns is too early — the
/// route is still animating out and rebuilds the field on the way.
class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.capitalization,
    this.hintText,
    this.confirmLabel,
    this.cancelLabel,
    this.initialValue,
  });

  final String title;
  final TextCapitalization capitalization;
  final String? hintText;
  final String? confirmLabel;
  final String? cancelLabel;
  final String? initialValue;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue ?? '';
    _controller = TextEditingController(text: initial);
    // Pre-select, so editing an existing value starts by replacing it.
    if (initial.isNotEmpty) {
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: initial.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: context.dialogSurface,
      title: Text(widget.title, style: TextStyle(color: context.txtPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.capitalization,
        style: TextStyle(color: context.txtPrimary),
        decoration: InputDecoration(hintText: widget.hintText),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel ?? l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.cyan),
          onPressed: _submit,
          child: Text(widget.confirmLabel ?? l.confirm),
        ),
      ],
    );
  }
}
