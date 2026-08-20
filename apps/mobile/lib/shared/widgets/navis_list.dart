import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/theme/tone.dart';
import 'package:navis_mobile/shared/widgets/navis_status_chip.dart';

/// Where a row's text starts, and therefore where its separator starts too, so
/// the hairlines line up with the labels instead of cutting the icons.
const double _textInset = Dimens.spaceXl + Dimens.spaceLg;

/// One row of a grouped list: label, optional detail, optional trailing value.
///
/// This is the app's single row primitive. It replaces the fifteen private
/// look-alikes that had accumulated one per screen — `_ActionTile` on the boat
/// hub, `_ProfileTile` on the profile, `_DetailRow` in the info section, plus
/// the hand-built rows in readiness, settings and the document list — which is
/// why no two lists in the app had the same height, inset or chevron.
///
/// Accessibility is built in, not per caller: the whole row is one semantic
/// node carrying label + value, it announces itself as a button when tappable,
/// and it is never shorter than [Dimens.minTouchTarget].
class NavisRow extends StatelessWidget {
  const NavisRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.value,
    this.valueColor,
    this.valueTone,
    this.lockLabel,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.dense = false,
  });

  final String title;

  /// Second line. Keep it to a real explanation — in the editorial layout most
  /// rows read better without one.
  final String? subtitle;

  final IconData? icon;

  /// Tints the icon. Pass a semantic accent (`context.caution`,
  /// `context.critical`) — never a fill-role colour, since this is a glyph.
  final Color? iconColor;

  /// Trailing text: a count, an amount, a status. Set in tabular figures so a
  /// column of them aligns.
  final String? value;
  final Color? valueColor;

  /// When set, [value] is drawn as a filled [NavisStatusChip] instead of tinted
  /// text. Use it for a status the user has to act on — and specifically for
  /// caution, which cannot be tinted text on a light canvas without turning
  /// brown.
  final NavisTone? valueTone;

  /// Marks the row as behind a plan, with the tier's name.
  ///
  /// Deliberately quiet — a lock glyph and muted ink, never a filled chip. The
  /// first version reused the caution chip for this, so «you have to pay» read
  /// exactly as loud as «your insurance has expired». Urgency has a date on it;
  /// availability does not.
  final String? lockLabel;

  /// Custom trailing widget (badge, switch). Wins over [value] and [lockLabel].
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Defaults to showing a chevron exactly when the row navigates.
  final bool? showChevron;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final chevron = showChevron ?? (onTap != null);
    final semanticValue = [
      if (subtitle != null) subtitle,
      if (value != null) value,
      if (lockLabel != null) lockLabel,
    ].join(', ');

    final row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: dense ? Dimens.minTouchTarget : 56,
      ),
      // The horizontal gutter belongs to the caller (a NavisList pads once for
      // the whole group); the row only owns its vertical rhythm.
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: dense ? Dimens.spaceSm : Dimens.spaceMd,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: Dimens.iconLg,
                color: iconColor ?? context.inkMuted,
              ),
              const SizedBox(width: Dimens.spaceLg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: NavisType.title3.copyWith(color: context.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: NavisType.bodySm.copyWith(color: context.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (lockLabel != null) ...[
              const SizedBox(width: Dimens.spaceSm),
              Icon(
                Icons.lock_outline_rounded,
                size: Dimens.iconSm,
                color: context.inkFaint,
              ),
              const SizedBox(width: Dimens.spaceXs),
              Text(
                lockLabel!,
                style: NavisType.overline.copyWith(color: context.inkMuted),
              ),
            ] else if (value != null) ...[
              const SizedBox(width: Dimens.spaceMd),
              // Flexible, not fixed: a long status used to squeeze the label
              // and break it mid-word.
              Flexible(
                child: valueTone != null
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: NavisStatusChip(
                          label: value!,
                          tone: valueTone!,
                        ),
                      )
                    : Text(
                        value!,
                        textAlign: TextAlign.end,
                        style: NavisType.label.copyWith(
                          color: valueColor ?? context.inkMuted,
                        ),
                      ),
              ),
            ],
            if (chevron) ...[
              const SizedBox(width: Dimens.spaceXs),
              Icon(
                Icons.chevron_right_rounded,
                size: Dimens.iconLg,
                color: context.inkFaint,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: title,
      value: semanticValue.isEmpty ? null : semanticValue,
      child: ExcludeSemantics(
        child: onTap == null
            ? row
            : InkWell(
                onTap: onTap,
                child: row,
              ),
      ),
    );
  }
}

/// A group of [NavisRow]s under an optional heading, separated by hairlines.
///
/// The editorial replacement for "wrap everything in a card": a heading in
/// [NavisType.overline] and rows divided by 1px lines carries the same grouping
/// with none of the nesting, and no per-card fill or border to pay for.
class NavisList extends StatelessWidget {
  const NavisList({
    super.key,
    required this.children,
    this.title,
    this.action,
    this.padding = Insets.gutter,
  });

  /// Rows. Separators are inserted between them, never above the first or
  /// below the last — the group is closed by the space around it.
  final List<Widget> children;

  /// Heading, rendered in tracked uppercase.
  final String? title;

  /// Trailing affordance on the heading row (an add button, a "see all").
  final Widget? action;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && title == null) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) _heading(context),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: Dimens.hairline,
                thickness: Dimens.hairline,
                indent: _textInset,
                color: context.hairline,
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _heading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: Dimens.spaceXl,
        bottom: Dimens.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            // Tracked uppercase is the editorial treatment, but a screen reader
            // spells all-caps out letter by letter, so the announced label is
            // the original string.
            child: Semantics(
              header: true,
              label: title,
              child: ExcludeSemantics(
                child: Text(
                  title!.toUpperCase(),
                  style: NavisType.overline.copyWith(color: context.inkMuted),
                ),
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
