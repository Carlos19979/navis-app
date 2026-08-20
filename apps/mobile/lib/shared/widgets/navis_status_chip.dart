import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/theme/tone.dart';

/// A short status, stated in words, on a filled pill.
///
/// This exists because of amber. The other accents have a darkened twin that is
/// still recognisably the same colour, so they can be tinted text on the light
/// canvas; amber does not — the shade that clears WCAG AA on white is brown.
/// So instead of darkening the colour until it stops being the colour, the
/// status is set in navy ink **on** the brand amber (7.32:1), which puts more
/// of the accent on screen than tinted text ever did.
///
/// The fill/ink pairing per tone lives on `ThemeColorsX.toneFill` /
/// `toneInk`, with the measured ratio for each.
///
/// Reserve it for what needs a decision. A [NavisTone.neutral] chip is plain
/// muted text with no fill, because a row that is simply fine does not need to
/// shout — three filled pills stacked in a list is noise, and then none of them
/// means anything.
class NavisStatusChip extends StatelessWidget {
  const NavisStatusChip({
    super.key,
    required this.label,
    this.tone = NavisTone.neutral,
    this.semanticLabel,
  });

  final String label;
  final NavisTone tone;

  /// Spoken instead of [label] when the compact form does not read well.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = NavisType.caption.copyWith(fontWeight: FontWeight.w600);

    if (tone == NavisTone.neutral) {
      return Semantics(
        label: semanticLabel,
        child: Text(
          label,
          textAlign: TextAlign.end,
          style: text.copyWith(color: context.inkMuted),
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.toneFill(tone),
          borderRadius: BorderRadius.circular(Dimens.radiusChip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spaceSm,
            vertical: 3,
          ),
          child: Text(
            label,
            style: text.copyWith(color: context.toneInk(tone)),
          ),
        ),
      ),
    );
  }
}
