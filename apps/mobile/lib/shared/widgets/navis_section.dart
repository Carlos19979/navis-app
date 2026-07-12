import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';

/// A consistent section header (small uppercase cyan label), replacing the
/// per-screen `_SectionHeader`/`_SectionTitle` variants.
class NavisSectionHeader extends StatelessWidget {
  const NavisSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.color = AppColors.cyan,
  });

  final String label;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spaceXs,
        Dimens.spaceLg,
        Dimens.spaceXs,
        Dimens.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A titled form section: header + a glass card wrapping [child]. Gives every
/// form the same rhythm instead of each hand-styling its sections.
class NavisSection extends StatelessWidget {
  const NavisSection({
    super.key,
    this.title,
    required this.child,
    this.headerTrailing,
    this.padding = const EdgeInsets.all(Dimens.spaceLg),
  });

  final String? title;
  final Widget child;
  final Widget? headerTrailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          NavisSectionHeader(label: title!, trailing: headerTrailing),
        NavisCard(padding: padding, child: child),
      ],
    );
  }
}
