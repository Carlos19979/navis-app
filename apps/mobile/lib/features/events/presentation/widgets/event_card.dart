import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// One regatta in the feed: when, what, where.
///
/// The date is the anchor, so it leads — but as *type*, not as a 56 dp gradient
/// block with its own drop shadow. That block, the star in a glowing disc and
/// the outlined «interested» pill made three decorated objects per row, and a
/// screenful of them had no reading order at all.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final day = event.startDate.day.toString();
    final month = DateFormat.MMM(locale).format(event.startDate).toUpperCase();

    return Semantics(
      button: true,
      label: event.name,
      value: [
        NavisDateUtils.formatDate(event.startDate),
        event.locationName,
        if (event.isInterested) l.interested,
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => context.go(Routes.event(event.id)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.hairline)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimens.spaceLg),
              child: Row(
                children: [
                  // Fixed width so a column of dates aligns; tabular figures so
                  // «1» and «28» occupy the same space.
                  SizedBox(
                    width: 44,
                    child: Column(
                      children: [
                        Text(
                          day,
                          style: NavisType.title1.copyWith(color: context.ink),
                        ),
                        Text(
                          month,
                          style: NavisType.overline.copyWith(
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Dimens.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (event.isFeatured) ...[
                              Icon(
                                Icons.star_rounded,
                                size: Dimens.iconSm,
                                color: context.caution,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                event.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NavisType.title3.copyWith(
                                  color: context.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${NavisDateUtils.formatTime(event.startDate)} · '
                          '${event.locationName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NavisType.caption.copyWith(
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (event.isInterested) ...[
                    const SizedBox(width: Dimens.spaceSm),
                    Icon(
                      Icons.check_circle_rounded,
                      size: Dimens.iconMd,
                      color: context.positive,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
