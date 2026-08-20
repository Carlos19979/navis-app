import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_pulse_budget.dart';

class NavisEmptyState extends StatelessWidget {
  const NavisEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String message;

  /// Optional secondary line under the message (e.g. a value proposition).
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A second way out of the empty screen.
  ///
  /// Some empty states have two honest answers and offering only one is a dead
  /// end: with no boats you can *add* one or *join* someone else's, and a crew
  /// member invited to a boat has no boat of their own to add.
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

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
              // The float is decorative: it plays a couple of times to catch
              // the eye and then rests, instead of repainting for as long as
              // the screen is open.
              RepaintBoundary(
                child: ExcludeSemantics(
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
                        onPlay: (controller) => controller.repeat(
                          reverse: true,
                          count: PulseBudget.reverseHalves(
                            PulseBudget.decorative,
                          ),
                        ),
                      )
                      .moveY(
                        begin: 0,
                        end: -6,
                        duration: 2000.ms,
                        curve: Curves.easeInOut,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                      ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Dimens.spaceXl),
                // Filled: on an empty screen this is *the* thing to do, and a
                // recessed button made it read as an aside.
                NavisButton(
                  label: actionLabel!,
                  compact: true,
                  onPressed: onAction!,
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: Dimens.spaceSm),
                NavisButton(
                  label: secondaryActionLabel!,
                  variant: NavisButtonVariant.secondary,
                  compact: true,
                  onPressed: onSecondaryAction!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
