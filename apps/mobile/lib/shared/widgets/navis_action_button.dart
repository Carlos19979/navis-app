import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';

/// A wide, labelled action — the shape Today, the forecast and the chart all
/// use to start something.
///
/// Pure presentation: what the tap does, and whether the user is allowed to do
/// it, is the caller's business. That split is deliberate — the *look* can be
/// shared without `shared/` learning about boats, trips or plans, which is the
/// one import direction this layer never takes.
class NavisActionButton extends StatelessWidget {
  const NavisActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.lockLabel,
    this.onDark = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// The one action the screen is nudging towards. At most one per row.
  final bool primary;

  /// A quiet plan marker — a lock and a muted overline, never a filled chip.
  /// A filled chip is for urgency with a date on it; "you could pay for this"
  /// is not that, and shouting it in the same colour as an expired insurance
  /// certificate is how the two stopped being distinguishable.
  final String? lockLabel;

  /// Set on media: over a photograph or a chart, where the surface tokens have
  /// nothing to sit on.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = switch ((primary, onDark)) {
      (true, _) => context.onAccent,
      (false, true) => context.onAccent,
      (false, false) => context.ink,
    };
    final bg = switch ((primary, onDark)) {
      (true, _) => context.accent,
      (false, true) => context.onMedia,
      (false, false) => context.surfaceSunken,
    };

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Dimens.radiusControl),
              border: primary
                  ? null
                  : Border.all(
                      color: onDark ? context.onMediaBorder : context.hairline,
                    ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.spaceMd,
                vertical: Dimens.spaceLg,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: Dimens.iconLg),
                  const SizedBox(width: Dimens.spaceSm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NavisType.label.copyWith(color: fg),
                    ),
                  ),
                  if (lockLabel != null) ...[
                    const SizedBox(width: Dimens.spaceSm),
                    Icon(
                      Icons.lock_outline_rounded,
                      size: Dimens.iconSm,
                      color: onDark
                          ? context.onAccent.withValues(alpha: 0.7)
                          : context.inkFaint,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      lockLabel!,
                      style: NavisType.overline.copyWith(
                        color: onDark
                            ? context.onAccent.withValues(alpha: 0.8)
                            : context.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width actions on one line. Empty in, nothing out — so a caller can
/// build the list from what the user is actually allowed to do without
/// guarding the row itself.
class NavisActionBar extends StatelessWidget {
  const NavisActionBar({super.key, required this.actions});

  final List<NavisActionButton> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final (i, action) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: Dimens.spaceMd),
          Expanded(child: action),
        ],
      ],
    );
  }
}
