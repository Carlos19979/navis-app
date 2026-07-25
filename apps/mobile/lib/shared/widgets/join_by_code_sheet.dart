import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

/// Shows a redesigned modal bottom sheet that collects an invite/share code.
/// Shared by both "join a club" (Community) and "join a shared boat" (My
/// boats) so the flow lives in one place. Returns the trimmed, uppercased code
/// or null when cancelled or left empty.
///
/// Kept intentionally generic: the caller supplies the [title], the friendly
/// [description] line explaining what a code is / where to get it, and an
/// optional field [hint].
Future<String?> showJoinByCodeSheet(
  BuildContext context, {
  required String title,
  required String description,
  String? hint,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JoinByCodeSheet(
      title: title,
      description: description,
      hint: hint,
    ),
  );
}

class _JoinByCodeSheet extends StatefulWidget {
  const _JoinByCodeSheet({
    required this.title,
    required this.description,
    this.hint,
  });

  final String title;
  final String description;
  final String? hint;

  @override
  State<_JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<_JoinByCodeSheet> {
  final _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final can = _controller.text.trim().isNotEmpty;
    if (can != _canSubmit) setState(() => _canSubmit = can);
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.dialogSurface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Dimens.radiusXxl),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          Dimens.spaceXl,
          Dimens.spaceMd,
          Dimens.spaceXl,
          Dimens.spaceXl + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: Dimens.spaceXl),
                decoration: BoxDecoration(
                  color: context.glassBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: Dimens.iconXl,
                  height: Dimens.iconXl,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.glassBg,
                    border: Border.all(color: context.glassBorderColor),
                  ),
                  child: const Icon(
                    Icons.vpn_key_outlined,
                    size: Dimens.iconSm,
                    color: AppColors.cyan,
                  ),
                ),
                const SizedBox(width: Dimens.spaceMd),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.txtPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceMd),
            Text(
              widget.description,
              style: TextStyle(fontSize: 14, color: context.txtSecondary),
            ),
            const SizedBox(height: Dimens.spaceLg),
            NavisTextField(
              controller: _controller,
              hint: widget.hint ?? l.inviteCode,
              prefixIcon: Icons.tag_rounded,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Dimens.spaceLg),
            NavisButton(
              label: l.join,
              icon: Icons.arrow_forward_rounded,
              isDisabled: !_canSubmit,
              onPressed: _submit,
            ),
            const SizedBox(height: Dimens.spaceSm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l.cancel,
                  style: TextStyle(color: context.txtSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
