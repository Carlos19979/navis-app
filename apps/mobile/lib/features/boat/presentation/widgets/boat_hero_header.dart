import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/palette.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/presentation/boat_type_label.dart';
import 'package:navis_mobile/features/boat/presentation/widgets/boat_switcher.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_ring.dart';

/// The opening of Today: the boat's own photograph, with its name on it.
///
/// The photo used to be a 96px strip under the heading, competing with the
/// readiness ring for the first look. As the header it does the opposite — it
/// says whose page this is before a single word is read.
///
/// **This is where the nautical glass belongs.** The score sits in a frosted
/// disc over the photograph, and that is the one place a `BackdropFilter` is
/// honest work: there is real detail behind it. It left the app bar and the
/// cards because there was nothing behind them but a flat canvas, where a blur
/// hands back the pixels it was given.
///
/// Without a photo there is nothing to frost, so the header is typographic and
/// the score moves to its own row below — see `TodayScreen`.
class BoatHeroHeader extends StatelessWidget {
  const BoatHeroHeader({
    super.key,
    required this.boat,
    required this.photoUrl,
    required this.score,
    required this.scoreColor,
    required this.onScoreTap,
    this.onPhotoTap,
  });

  final Boat boat;
  final String photoUrl;

  /// Null while the readiness summary is still in flight: the disc holds its
  /// place rather than popping in and shifting the header's contents.
  final int? score;
  final Color scoreColor;

  final VoidCallback onScoreTap;
  final VoidCallback? onPhotoTap;

  static const _height = 232.0;
  static const _discSize = 84.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return SizedBox(
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onPhotoTap,
            child: CachedNetworkImage(
              imageUrl: photoUrl,
              memCacheWidth: 1200,
              fit: BoxFit.cover,
              // Navy, not a light surface: the name and the score sit on
              // this in white, so a pale placeholder means they are invisible
              // for as long as the photo takes to arrive — and invisible again
              // if it never does.
              placeholder: (_, __) => const ColoredBox(color: Palette.navy),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: Palette.navy),
            ),
          ),
          // Three stops, not two: the name needs a dark enough floor at the
          // bottom while the middle of the photo stays visible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.45, 1],
                colors: [
                  Color(0x00000000),
                  Color(0x33000000),
                  Color(0xD9000000),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            left: Dimens.spaceLg,
            right: _discSize + Dimens.spaceXl,
            bottom: Dimens.spaceLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.today.toUpperCase(),
                  style: NavisType.overline.copyWith(
                    color: Palette.onAccent.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                BoatSwitcher(boat: boat, onDark: true),
                Text(
                  [
                    localizedBoatType(l, boat.type),
                    if (boat.homePort != null) boat.homePort!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NavisType.bodySm.copyWith(
                    color: Palette.onAccent.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: Dimens.spaceLg,
            bottom: Dimens.spaceLg,
            child: _ScoreDisc(
              score: score,
              color: scoreColor,
              onTap: onScoreTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreDisc extends StatelessWidget {
  const _ScoreDisc({
    required this.score,
    required this.color,
    required this.onTap,
  });

  final int? score;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      value: score == null ? null : '$score',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: BackdropFilter(
              // The one blur that earns its cost on this screen: a photograph
              // behind it, blurred once, in a fixed 84dp circle.
              filter: ImageFilter.blur(
                sigmaX: Dimens.blurControls,
                sigmaY: Dimens.blurControls,
              ),
              child: Container(
                width: BoatHeroHeader._discSize,
                height: BoatHeroHeader._discSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.navy.withValues(alpha: 0.42),
                  border: Border.all(
                    color: Palette.onAccent.withValues(alpha: 0.28),
                  ),
                ),
                child: score == null
                    ? null
                    : NavisRingOnMedia(score: score!, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
