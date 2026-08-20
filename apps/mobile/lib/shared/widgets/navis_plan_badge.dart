import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// The amber "PRO" / "PLUS" pill that marks an entry point as paid.
///
/// One widget so every gated feature is marked the same way. It started as an
/// inline container on the cost-intelligence row only, which made that the one
/// paid feature users could recognise before tapping it.
class NavisPlanBadge extends StatelessWidget {
  const NavisPlanBadge({super.key, required this.label, this.compact = false});

  final String label;

  /// Tighter padding and no letter-spacing, for badges pinned to a corner.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Opaque, so it stays readable pinned to a photo or a FAB, but *quiet*.
        // It marks availability, not urgency: a solid amber pill here shouted as
        // loud as an expired document, and the two are not the same news.
        color: Color.alphaBlend(
          context.ink.withValues(alpha: 0.72),
          Theme.of(context).colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.canvas,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 9 : null,
              letterSpacing: compact ? 0 : 0.5,
            ),
      ),
    );
  }
}

/// A [NavisPlanBadge] pinned to the top-right corner of [child].
///
/// For controls with no room for a pill inline — a FAB, an icon button.
class NavisPlanBadged extends StatelessWidget {
  const NavisPlanBadged({
    super.key,
    required this.child,
    required this.label,
    this.show = true,
  });

  final Widget child;
  final String label;

  /// False leaves [child] untouched: the user already has the plan.
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: NavisPlanBadge(label: label, compact: true),
        ),
      ],
    );
  }
}
