import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// One voyage in the logbook.
///
/// Editorial row rather than a card of glass pills: the route is the headline,
/// the date is the byline, and the three figures are one quiet metadata line.
/// The pills each carried a fill, a border and a tinted icon, so a screenful of
/// trips was thirty framed objects competing with each other — and two
/// `ShaderMask`s per row, to tint an icon, which is a shader pass per row per
/// frame.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    final route = trip.arrivalPort == null
        ? trip.departurePort
        : '${trip.departurePort} \u2192 ${trip.arrivalPort}';

    final figures = [
      if (trip.distanceNm != null)
        Measure.distance(locale, trip.distanceNm!, l.nauticalMiles),
      if (trip.duration != null) NavisDateUtils.formatDuration(trip.duration!),
      if (trip.avgSpeedKnots != null)
        Measure.knots(locale, trip.avgSpeedKnots!, l.knots),
    ].join(' \u00b7 ');

    return Semantics(
      button: true,
      label: route,
      value: [NavisDateUtils.formatDateTime(trip.departureTime), figures]
          .where((s) => s.isNotEmpty)
          .join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => context.push(Routes.trip(trip.id)),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.hairline)),
            ),
            padding: const EdgeInsets.symmetric(vertical: Dimens.spaceLg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NavisType.title3.copyWith(color: context.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        NavisDateUtils.formatDateTime(trip.departureTime),
                        style: NavisType.caption.copyWith(
                          color: context.inkMuted,
                        ),
                      ),
                      if (figures.isNotEmpty) ...[
                        const SizedBox(height: Dimens.spaceXs),
                        Text(
                          figures,
                          style: NavisType.caption.copyWith(
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: Dimens.iconLg,
                  color: context.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
