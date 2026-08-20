import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/motion.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

enum NavisButtonVariant { primary, secondary, danger }

/// The app's button.
///
/// Flat by design: the old one carried a coloured glow under every primary and
/// danger button, which on a white canvas reads as a bruise. The lift is kept
/// for exactly one control — the floating action button — where it is what
/// makes it read as floating.
///
/// `primary` and `danger` fill with the **ink** accent, not the bright one, so
/// the white label on top clears WCAG AA (5.55:1 and 6.54:1). `secondary` is a
/// recessed surface with a hairline, not a tinted accent, so a screen can offer
/// a second action without two things competing for the eye.
class NavisButton extends StatefulWidget {
  const NavisButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.variant = NavisButtonVariant.primary,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final NavisButtonVariant variant;
  final bool compact;

  @override
  State<NavisButton> createState() => _NavisButtonState();
}

class _NavisButtonState extends State<NavisButton> {
  bool _pressed = false;

  Color _fill(BuildContext context) => switch (widget.variant) {
        NavisButtonVariant.primary => context.accent,
        NavisButtonVariant.secondary => context.surfaceSunken,
        NavisButtonVariant.danger => context.critical,
      };

  Color _label(BuildContext context) => switch (widget.variant) {
        NavisButtonVariant.primary => context.onAccent,
        NavisButtonVariant.secondary => context.ink,
        NavisButtonVariant.danger => context.onAccent,
      };

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading || widget.isDisabled;
    final height = widget.compact ? 44.0 : 52.0;
    final outlined = widget.variant == NavisButtonVariant.secondary;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: disabled ? null : () => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: Motion.fast,
          curve: Motion.curve,
          child: AnimatedOpacity(
            opacity: disabled ? 0.45 : 1.0,
            duration: Motion.fast,
            child: Container(
              height: height,
              width: widget.compact ? null : double.infinity,
              padding: widget.compact
                  ? const EdgeInsets.symmetric(horizontal: Dimens.spaceXl)
                  : null,
              decoration: BoxDecoration(
                color: _fill(context),
                borderRadius: BorderRadius.circular(Dimens.radiusControl),
                border: outlined ? Border.all(color: context.hairline) : null,
              ),
              child: Center(
                child: widget.isLoading ? _loading(context) : _content(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    return SizedBox(
      width: Dimens.iconLg,
      height: Dimens.iconLg,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: _label(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final color = _label(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: Dimens.iconMd, color: color),
          const SizedBox(width: Dimens.spaceSm),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NavisType.label.copyWith(fontSize: 15, color: color),
          ),
        ),
      ],
    );
  }
}
