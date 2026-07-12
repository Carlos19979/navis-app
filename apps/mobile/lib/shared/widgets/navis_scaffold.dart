import 'package:flutter/material.dart';

import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';

/// The standard screen chrome: transparent [Scaffold] + [NavisAppBar] over the
/// nautical [GradientBackground], inside a [SafeArea]. Replaces the
/// `Scaffold → NavisAppBar → GradientBackground → SafeArea` boilerplate copied
/// across nearly every screen and centralizes bottom-nav clearance.
class NavisScaffold extends StatelessWidget {
  const NavisScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = false,
    this.actions,
    this.appBarBottom,
    this.floatingActionButton,
    this.transparentAppBar = false,
    this.showProfileAction = true,
    this.safeAreaBottom = true,
  });

  final String title;
  final Widget body;
  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBarBottom;
  final Widget? floatingActionButton;
  final bool transparentAppBar;

  /// Whether the app bar appends the profile shortcut. Set false once Profile
  /// is a first-class tab (phase 2).
  final bool showProfileAction;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: transparentAppBar,
      appBar: NavisAppBar(
        title: title,
        showBack: showBack,
        actions: actions,
        transparent: transparentAppBar,
        bottom: appBarBottom,
        showProfileAction: showProfileAction,
      ),
      floatingActionButton: floatingActionButton,
      body: GradientBackground(
        child: SafeArea(
          bottom: safeAreaBottom,
          child: body,
        ),
      ),
    );
  }
}
