import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class NavisAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavisAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Go back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/boats');
                }
              },
            )
          : null,
      actions: [
        ...?actions,
        IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: 'Profile',
          onPressed: () => context.go('/profile'),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navy,
              AppColors.darkSurface,
            ],
          ),
        ),
      ),
    );
  }
}
