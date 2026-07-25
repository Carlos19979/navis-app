import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
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
    this.bottomNavClearance = false,
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

  /// When true, pads the body bottom by [Dimens.navClearance] so its last item
  /// clears the floating bottom nav. Opt-in (default false) so pushed screens —
  /// which sit above the shell and never see the nav — are unaffected. Screens
  /// that already pad their own scroll view (e.g. via [Insets.screenWithNav])
  /// should leave this false to avoid doubling the clearance.
  final bool bottomNavClearance;

  @override
  Widget build(BuildContext context) {
    // Tab screens (safeAreaBottom: false) sit under the floating bottom nav,
    // which overlays this scaffold from the shell: an unpadded FAB lands
    // BEHIND the nav and taps hit the nav's rightmost item instead. Lift it
    // above the nav clearance (16 = the FAB's own default margin).
    final fab = floatingActionButton != null && !safeAreaBottom
        ? Padding(
            padding: const EdgeInsets.only(bottom: Dimens.navClearance - 16),
            child: floatingActionButton,
          )
        : floatingActionButton;
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
      floatingActionButton: fab,
      body: GradientBackground(
        child: SafeArea(
          bottom: safeAreaBottom,
          child: bottomNavClearance
              ? Padding(
                  padding: const EdgeInsets.only(
                    bottom: Dimens.navClearance,
                  ),
                  child: body,
                )
              : body,
        ),
      ),
    );
  }
}
