import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/palette.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// The app bar: a left-aligned title on the page's own canvas, closed by a
/// hairline.
///
/// **It no longer blurs.** The old bar wrapped a `BackdropFilter(20)` around a
/// translucent navy fill, which produced the grey band sitting above a lighter
/// body in every screenshot. It was also pure cost: blur returns what is behind
/// it, and behind it is a flat colour (light) or a smooth vertical gradient
/// (dark) — blurring either gives the same pixels back. This is exactly the
/// argument that removed the blur from `NavisCard`, and it applies to every
/// screen, so the app now pays for a backdrop filter only where there is real
/// detail underneath: set [overMedia] on the map and photo screens.
class NavisAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NavisAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
    this.transparent = false,
    this.overMedia = false,
    this.bottom,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  /// No fill and no hairline: the body's own artwork reads through. Pair with
  /// `extendBodyBehindAppBar`.
  final bool transparent;

  /// Blurred translucent fill, for a bar floating over a map or a photograph —
  /// the only case where a backdrop filter buys anything.
  final bool overMedia;

  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final bar = AppBar(
      title: Text(title, style: _titleStyle(context)),
      titleSpacing: showBack ? 0 : Dimens.spaceLg,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      // No explicit leadingWidth: the default keeps the back button's ink
      // response inside the toolbar instead of stretching it into the very
      // corner of the screen, where it would swallow taps meant for whatever
      // is layered above (a modal sheet's barrier, for one).
      leading: showBack ? _BackButton() : null,
      actions: actions,
      bottom: bottom,
    );

    if (transparent) return bar;

    if (overMedia) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: Dimens.blurAppBar,
            sigmaY: Dimens.blurAppBar,
          ),
          child: ColoredBox(
            color: Palette.navy.withValues(alpha: 0.62),
            child: bar,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.canvas,
        border: Border(
          bottom: BorderSide(
            color: context.hairline,
          ),
        ),
      ),
      child: bar,
    );
  }

  TextStyle _titleStyle(BuildContext context) {
    final color = overMedia ? Palette.inkOnDark : context.ink;
    return NavisType.title2.copyWith(color: color);
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      iconSize: Dimens.iconMd,
      tooltip: AppLocalizations.of(context)!.goBack,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.today);
        }
      },
    );
  }
}
