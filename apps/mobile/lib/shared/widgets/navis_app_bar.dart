import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

class NavisAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavisAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
    this.transparent = false,
    this.bottom,
    this.showProfileAction = true,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final bool transparent;
  final PreferredSizeWidget? bottom;

  /// Whether to append the circular profile shortcut. False once Profile is a
  /// bottom-nav tab.
  final bool showProfileAction;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

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
        bottom: bottom,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark
        ? AppColors.navy.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.85);
    final borderColor =
        isDark ? context.glassBorderColor : AppColors.lightDivider;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
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
            bottom: bottom,
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      tooltip: AppLocalizations.of(context)!.goBack,
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
    if (!showProfileAction) {
      return [...?actions];
    }
    return [
      ...?actions,
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Container(
          decoration: BoxDecoration(
            color: context.glassBg,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.person_outline_rounded, size: 22),
            tooltip: AppLocalizations.of(context)!.profile,
            onPressed: () => context.go('/profile'),
          ),
        ),
      ),
    ];
  }
}
