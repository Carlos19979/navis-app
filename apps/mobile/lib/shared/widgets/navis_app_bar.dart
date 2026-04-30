import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';

class NavisAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavisAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
    this.transparent = false,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final bool transparent;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (transparent) {
      return AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: showBack ? _buildBackButton(context) : null,
        actions: _buildActions(context),
      );
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.7),
            border: const Border(
              bottom: BorderSide(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
          ),
          child: AppBar(
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: showBack ? _buildBackButton(context) : null,
            actions: _buildActions(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      tooltip: 'Go back',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/boats');
        }
      },
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      ...?actions,
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.glassWhite,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 22),
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
          ),
        ),
      ),
    ];
  }
}
