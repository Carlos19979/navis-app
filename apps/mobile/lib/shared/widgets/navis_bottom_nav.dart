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

class NavisBottomNav extends ConsumerWidget {
  const NavisBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    // Sit lower by eating into the bottom safe-area inset (clamped so it never
    // goes off-screen on devices without a home indicator).
    final bottomPadding = (MediaQuery.of(context).padding.bottom - 10)
        .clamp(0.0, double.infinity);

    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, l.home),
      _NavItem(Icons.map_outlined, Icons.map_rounded, l.charts),
      _NavItem(Icons.cloud_outlined, Icons.cloud_rounded, l.weather),
      _NavItem(Icons.groups_outlined, Icons.groups_rounded, l.community),
      _NavItem(Icons.person_outline_rounded, Icons.person_rounded, l.profile),
    ];

    // A dark-navy glass pill floats over content in both themes; on light it
    // gets a translucent surface tint so it doesn't read as a black slab.
    final pillColor = isDark
        ? AppColors.navy.withValues(alpha: 0.85)
        : AppColors.lightSurface.withValues(alpha: 0.9);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        extendBody: true,
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            left: Dimens.spaceXl,
            right: Dimens.spaceXl,
            bottom: bottomPadding + 2,
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
                  boxShadow: Shadows.nav,
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
                      ? AppColors.cyan.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Dimens.radiusMd),
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppColors.cyan : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.cyan : inactiveColor,
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
