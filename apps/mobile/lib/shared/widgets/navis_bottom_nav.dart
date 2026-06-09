import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';

class NavisBottomNav extends ConsumerWidget {
  const NavisBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    // Sit lower by eating into the bottom safe-area inset (clamped so it never
    // goes off-screen on devices without a home indicator).
    final bottomPadding = (MediaQuery.of(context).padding.bottom - 10)
        .clamp(0.0, double.infinity);

    final items = [
      _NavItem(
        icon: Icons.sailing_outlined,
        activeIcon: Icons.sailing,
        label: l.boats,
      ),
      _NavItem(
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
        label: l.charts,
      ),
      _NavItem(
        icon: Icons.cloud_outlined,
        activeIcon: Icons.cloud,
        label: l.weather,
      ),
      _NavItem(
        icon: Icons.event_outlined,
        activeIcon: Icons.event,
        label: l.events,
      ),
      const _NavItem(
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        label: 'Grupos',
      ),
    ];

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        extendBody: true,
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: bottomPadding + 2,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isActive = navigationShell.currentIndex == index;
                    return _NavBarItem(
                      item: item,
                      isActive: isActive,
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
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.cyan.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? AppColors.cyan : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.cyan : AppColors.textSecondary,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
