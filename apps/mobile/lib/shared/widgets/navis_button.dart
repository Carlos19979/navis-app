import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

enum NavisButtonVariant { primary, secondary, danger }

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

  LinearGradient get _gradient => switch (widget.variant) {
        NavisButtonVariant.primary => AppColors.cyanGradient,
        NavisButtonVariant.secondary => const LinearGradient(
            colors: [AppColors.glassWhite, AppColors.glassWhite],
          ),
        NavisButtonVariant.danger => AppColors.redGradient,
      };

  Color get _textColor => switch (widget.variant) {
        NavisButtonVariant.primary => Colors.white,
        NavisButtonVariant.secondary => AppColors.cyan,
        NavisButtonVariant.danger => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading || widget.isDisabled;
    final height = widget.compact ? 44.0 : 52.0;

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: disabled
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: disabled
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: disabled
            ? null
            : () => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedOpacity(
            opacity: disabled ? 0.5 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: height,
              width: widget.compact ? null : double.infinity,
              padding: widget.compact
                  ? const EdgeInsets.symmetric(horizontal: 24)
                  : null,
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(14),
                border: widget.variant == NavisButtonVariant.secondary
                    ? Border.all(color: AppColors.glassBorder)
                    : null,
                boxShadow:
                    widget.variant != NavisButtonVariant.secondary
                        ? [
                            BoxShadow(
                              color: (widget.variant ==
                                          NavisButtonVariant.danger
                                      ? AppColors.red
                                      : AppColors.cyan)
                                  .withValues(
                                      alpha: disabled ? 0 : 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? _buildLoadingIndicator()
                    : _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: _textColor,
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: _textColor),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
