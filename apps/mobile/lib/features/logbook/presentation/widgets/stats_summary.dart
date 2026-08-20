import 'package:flutter/material.dart';

import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_metric.dart';

/// The logbook's totals: trips, distance, hours.
///
/// Through [NavisMetricGrid] now, like every other set of figures in the app.
/// It used to be a card of three tinted icon discs with the values in cyan —
/// three focal points before the first trip in the list, and a distance printed
/// as «142 NM» with `toStringAsFixed`, which is `142 MN` in Spanish.
class StatsSummary extends StatelessWidget {
  const StatsSummary({super.key, required this.stats});

  final TripStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return NavisMetricGrid(
      children: [
        NavisMetric(value: '${stats.totalTrips}', label: l.tripsLabel),
        NavisMetric(
          value: Measure.nauticalMiles(
            locale,
            stats.totalDistanceNm,
            l.nauticalMiles,
          ),
          label: l.distance,
        ),
        NavisMetric(
          value: Measure.decimal(locale, stats.totalHours, digits: 0),
          label: l.hoursLabel,
        ),
      ],
    );
  }
}
