import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';

/// The standard screen chrome: transparent [Scaffold] + [NavisAppBar] over the
/// page canvas, inside a [SafeArea]. Replaces the
/// `Scaffold → NavisAppBar → GradientBackground → SafeArea` boilerplate that
/// 26 of the app's 37 screens still copy by hand, and centralizes bottom-nav
/// clearance.
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
    this.appBarOverMedia = false,
    this.safeAreaBottom = true,
    this.bottomNavClearance = false,
  });

  final String title;
  final Widget body;
  final bool showBack;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBarBottom;
  final Widget? floatingActionButton;

  /// No app-bar fill and no hairline; pair with body artwork that reads
  /// through.
  final bool transparentAppBar;

  /// Blurred app bar, for a screen whose body is a map or a photograph.
  final bool appBarOverMedia;

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
    // BEHIND the nav and taps hit the nav's rightmost item instead.
    //
    // Lifted to the pill's actual top edge plus a gap — computed from the same
    // helper the pill uses, so the two cannot drift. `Dimens.spaceLg` comes off
    // because that is the FAB's own default margin, already applied by the
    // Scaffold.
    final fab = floatingActionButton != null && !safeAreaBottom
        ? Padding(
            padding: EdgeInsets.only(
              bottom: Dimens.navPillTop(MediaQuery.of(context).padding.bottom) +
                  Dimens.spaceSm -
                  Dimens.spaceLg,
            ),
            child: floatingActionButton,
          )
        : floatingActionButton;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: transparentAppBar || appBarOverMedia,
      appBar: NavisAppBar(
        title: title,
        showBack: showBack,
        actions: actions,
        transparent: transparentAppBar,
        overMedia: appBarOverMedia,
        bottom: appBarBottom,
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
