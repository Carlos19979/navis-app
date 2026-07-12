import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// The single glass text field. Replaces the duplicated `_GlassTextField`
/// (login + register), the ~36 inline `InputDecoration`s, and the per-form
/// `_field` helpers. Relies on the app's `InputDecorationTheme` for the glass
/// fill/border and adds the circular prefix-icon treatment used in auth.
class NavisTextField extends StatelessWidget {
  const NavisTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.circlePrefix = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final bool autofocus;

  /// Render the prefix icon inside a circular glass badge (the auth style).
  final bool circlePrefix;

  @override
  Widget build(BuildContext context) {
    Widget? prefix;
    if (prefixIcon != null) {
      prefix = circlePrefix
          ? Container(
              width: Dimens.iconXl,
              height: Dimens.iconXl,
              margin: const EdgeInsets.only(left: 8, right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.glassBg,
                border: Border.all(color: context.glassBorderColor),
              ),
              child: Icon(prefixIcon,
                  size: Dimens.iconSm, color: context.txtSecondary),
            )
          : Icon(prefixIcon, color: context.txtSecondary);
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      enabled: enabled,
      autofocus: autofocus,
      style: TextStyle(color: context.txtPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
    );
  }
}
