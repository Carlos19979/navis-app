import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

class NavisEmptyState extends StatelessWidget {
  const NavisEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: context.glassBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.glassBorderColor,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: context.txtSecondary.withValues(alpha: 0.6),
                  ),
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .moveY(
                      begin: 0,
                      end: -6,
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.txtSecondary,
                    ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                NavisButton(
                  label: actionLabel!,
                  variant: NavisButtonVariant.secondary,
                  compact: true,
                  onPressed: onAction!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
