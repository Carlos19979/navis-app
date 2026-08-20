import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/shadows.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';

/// The bottom-nav shell: a transparent [Scaffold] with `extendBody: true` and a
/// floating glass pill ([Dimens.bottomNavHeight]) that overlays the branch
/// content of the 5 tabs.
///
/// Bottom-nav clearance is intentionally the *screen's* responsibility, NOT
/// injected here: because the pill floats over `extendBody` content, each tab
/// screen must pad its own scroll view so its last item clears the pill. Inject
/// a MediaQuery bottom inset here and every screen that already pads would
/// double up. The single source of the clearance value is
/// [Dimens.navClearance] (or the ready-made [Insets.screenWithNav] padding) —
/// use one of those, never a hardcoded 100/112/130.
class NavisBottomNav extends ConsumerWidget {
  const NavisBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    // Sit lower by eating into the bottom safe-area inset (clamped so it never
    // goes off-screen on devices without a home indicator).
    // The shared helper: the scaffold lifts a tab's FAB to this same edge.
    final bottomPadding =
        Dimens.navPillInset(MediaQuery.of(context).padding.bottom);

    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, l.home),
      _NavItem(Icons.map_outlined, Icons.map_rounded, l.charts),
      _NavItem(Icons.cloud_outlined, Icons.cloud_rounded, l.weather),
      _NavItem(Icons.groups_outlined, Icons.groups_rounded, l.community),
      _NavItem(Icons.person_outline_rounded, Icons.person_rounded, l.account),
    ];

    // A dark-navy glass pill floats over content in both themes; on light it
    // gets a translucent surface tint so it doesn't read as a black slab.
    final pillColor = isDark
        ? AppColors.navy.withValues(alpha: 0.85)
        : context.surfaceRaised.withValues(alpha: 0.9);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        extendBody: true,
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            left: Dimens.spaceXl,
            right: Dimens.spaceXl,
            bottom: bottomPadding,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.radiusXxl),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: Dimens.blurNav,
                sigmaY: Dimens.blurNav,
              ),
              child: Container(
                height: Dimens.bottomNavHeight,
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(Dimens.radiusXxl),
                  border: Border.all(
                    color: context.glassBorderColor,
                    width: 0.5,
                  ),
                  boxShadow: Shadows.nav(isDark: isDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    return _NavBarItem(
                      item: items[index],
                      isActive: navigationShell.currentIndex == index,
                      onTap: () => navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = context.txtSecondary;
    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          height: Dimens.minTouchTarget,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimens.spaceLg,
                  vertical: Dimens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? context.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Dimens.radiusMd),
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? context.accent : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? context.accent : inactiveColor,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
