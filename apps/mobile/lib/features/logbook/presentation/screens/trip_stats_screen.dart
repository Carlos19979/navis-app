import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/app_typography.dart';
import 'package:navis_mobile/core/utils/measure_utils.dart';
import 'package:navis_mobile/shared/widgets/navis_list.dart';
import 'package:navis_mobile/shared/widgets/navis_section.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/features/logbook/domain/trip_period_stats.dart';
import 'package:navis_mobile/features/logbook/presentation/providers/logbook_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/models/analytics_period.dart';
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_bar_chart.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_period_picker.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_metric.dart';

/// Nothing to show for a figure that has no value yet.
const _dash = '\u2014';

/// Which slice of the logbook is on screen. Per boat, and reset when the screen
/// is left: coming back to "everything" is the useful default.
final _periodProvider = StateProvider.autoDispose<AnalyticsPeriod>(
  (ref) => const AnalyticsPeriod.allTime(),
);

/// The logbook in figures, for any period the owner picks.
///
/// The previous version showed two fixed blocks — all time, and the current
/// year — with the year block reduced to three of the eight figures. Everything
/// is now computed for the selected period instead: pick a year, then a month,
/// and every card follows.
class TripStatsScreen extends ConsumerWidget {
  const TripStatsScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tripsAsync = ref.watch(allBoatTripsProvider(boatId));

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: NavisAppBar(title: l.tripStatistics, showBack: true),
        body: tripsAsync.when(
          loading: () => const NavisShimmer(itemHeight: 120),
          error: (error, _) => NavisErrorWidget(
            message: error.toString(),
            onRetry: () => ref.invalidate(allBoatTripsProvider(boatId)),
          ),
          data: (trips) {
            if (trips.isEmpty) {
              return NavisEmptyState(
                icon: Icons.insights_outlined,
                message: l.noTrips,
                description: l.statsEmptyDescription,
                actionLabel: l.recordTrip,
                onAction: () => context.push(Routes.boatPrecheck(boatId)),
              );
            }
            return _StatsBody(trips: trips);
          },
        ),
      ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final years = yearsWithTrips(trips);
    var period = ref.watch(_periodProvider);

    // A year can disappear from under the selection when the list reloads.
    if (period.year != null && !years.contains(period.year)) {
      period = const AnalyticsPeriod.allTime();
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    final selected = trips.where((t) => period.contains(t.departureTime));
    final stats = aggregateTrips(selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, Dimens.spaceXxl),
      children: [
        NavisPeriodPicker(
          period: period,
          years: years,
          monthsWithData: period.year == null
              ? const {}
              : monthsWithTrips(trips, period.year!),
          onChanged: (next) => ref.read(_periodProvider.notifier).state = next,
        ),
        const SizedBox(height: 16),
        _HeadlineCard(period: period, stats: stats),
        const SizedBox(height: 12),
        NavisMetricGrid(children: [
          // No per-metric colour: six figures in four different accents is
          // colour used as decoration, and it leaves nothing for the one
          // number that would actually need flagging.
          NavisMetric(
            icon: Icons.route_rounded,
            value: stats.trips.toString(),
            label: l.totalTrips,
          ),
          NavisMetric(
            icon: Icons.anchor_rounded,
            value: stats.portCount.toString(),
            label: l.portsVisited,
          ),
          NavisMetric(
            icon: Icons.speed_rounded,
            value: _knots(locale, l, stats.topSpeedKn),
            label: l.topSpeed,
          ),
          NavisMetric(
            icon: Icons.trending_up_rounded,
            value: _knots(locale, l, stats.avgSpeedKn),
            label: l.averageSpeed,
          ),
          NavisMetric(
            icon: Icons.local_gas_station_rounded,
            value: stats.fuelL > 0
                ? Measure.litres(locale, stats.fuelL, 'L')
                : _dash,
            label: l.fuelConsumed,
          ),
          NavisMetric(
            icon: Icons.engineering_rounded,
            value: stats.engineHours > 0
                ? Measure.hours(locale, stats.engineHours, 'h')
                : _dash,
            label: l.totalEngineHours,
          ),
        ]),
        const SizedBox(height: 12),
        _AveragesCard(stats: stats),
        if (!period.isAllTime && period.month == null) ...[
          const SizedBox(height: 12),
          _monthlyChart(
              context,
              l,
              stats,
              period.year!,
              (month) => ref.read(_periodProvider.notifier).state =
                  AnalyticsPeriod.month(period.year!, month)),
        ],
        if (stats.ports.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PortsCard(ports: stats.ports),
        ],
      ],
    );
  }

  /// `kt`, not `kn`: this screen was the only place in the app using the other
  /// abbreviation, so the same speed read differently here than on the trip it
  /// came from.
  static String _knots(String locale, AppLocalizations l, double? value) =>
      value == null || value <= 0
          ? _dash
          : Measure.knots(locale, value, l.knots);

  /// Trips per month for the selected year. Tapping a bar drills into that
  /// month, which is also the discoverable way into the month filter.
  static Widget _monthlyChart(
    BuildContext context,
    AppLocalizations l,
    TripPeriodStats stats,
    int year,
    ValueChanged<int> onMonthTap,
  ) {
    final monthNames = navisShortMonthNames(context);
    return NavisBarChart(
      title: l.monthlyActivity,
      bars: [
        for (var i = 0; i < 12; i++)
          NavisBar(
            label: monthNames[i],
            value: stats.tripsByMonth[i].toDouble(),
            valueLabel: '${stats.tripsByMonth[i]}',
            semanticsLabel: '${monthNames[i]} $year: ${stats.tripsByMonth[i]}',
            onTap: () => onMonthTap(i + 1),
          ),
      ],
    );
  }
}

/// Distance and time for the period, given the room they deserve: they are the
/// two numbers an owner actually quotes about a season.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.period, required this.stats});

  final AnalyticsPeriod period;
  final TripPeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _periodLabel(context, l, period),
          style: NavisType.overline.copyWith(color: context.inkMuted),
        ),
        const SizedBox(height: Dimens.spaceXs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Measure.decimal(
                    locale,
                    stats.distanceNm,
                    digits: stats.distanceNm < 10 ? 1 : 0,
                  ),
                  maxLines: 1,
                  style: NavisType.numeral.copyWith(color: context.ink),
                ),
              ),
            ),
            const SizedBox(width: Dimens.spaceSm),
            Text(
              l.nauticalMiles,
              style: NavisType.title3.copyWith(color: context.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: Dimens.spaceXs),
        Text(
          l.statsHoursAndTrips(
            Measure.decimal(locale, stats.hours),
            stats.trips,
          ),
          style: NavisType.bodySm.copyWith(color: context.inkMuted),
        ),
      ],
    );
  }

  static String _periodLabel(
    BuildContext context,
    AppLocalizations l,
    AnalyticsPeriod period,
  ) {
    if (period.isAllTime) return l.allTime.toUpperCase();
    if (period.month == null) return '${period.year}';
    final month = DateFormat.MMMM(Localizations.localeOf(context).languageCode)
        .format(DateTime(period.year!, period.month!));
    return '${_capitalize(month)} ${period.year}';
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

/// Per-trip and per-mile averages. Consumption is in litres per mile — the
/// money side of the same data lives in Cost intelligence and is not repeated.
class _AveragesCard extends StatelessWidget {
  const _AveragesCard({required this.stats});

  final TripPeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rows = <(IconData, String, String)>[
      if (stats.avgTripNm != null)
        (
          Icons.straighten_rounded,
          l.statsAvgTrip,
          Measure.nauticalMiles(locale, stats.avgTripNm!, l.nauticalMiles),
        ),
      if (stats.longestTripNm > 0)
        (
          Icons.flag_rounded,
          l.statsLongestTrip,
          Measure.nauticalMiles(locale, stats.longestTripNm, l.nauticalMiles),
        ),
      if (stats.litresPerNm != null)
        (
          Icons.opacity_rounded,
          l.statsLitresPerNm,
          '${Measure.decimal(locale, stats.litresPerNm!, digits: 2)} '
              'L/${l.nauticalMiles}',
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return NavisList(
      padding: EdgeInsets.zero,
      children: [
        for (final (icon, label, value) in rows)
          NavisRow(icon: icon, title: label, value: value),
      ],
    );
  }
}

/// Ports of the period with their visit counts, most visited first.
///
/// The old screen counted ports and showed only the number; which ports they
/// were is the part worth reading.
class _PortsCard extends StatelessWidget {
  const _PortsCard({required this.ports});

  final List<PortVisits> ports;

  /// Enough to see the pattern without turning the card into a list screen.
  static const _maxShown = 8;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final shown = ports.take(_maxShown).toList();
    final rest = ports.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavisSectionHeader(label: l.portsVisited),
        Padding(
          padding: const EdgeInsets.only(top: Dimens.spaceSm),
          child: Wrap(
            spacing: Dimens.spaceSm,
            runSpacing: Dimens.spaceSm,
            children: [
              for (final port in shown)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.glassBg,
                    borderRadius: BorderRadius.circular(Dimens.radiusChip),
                    border: Border.all(color: context.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        port.port,
                        style: NavisType.label.copyWith(color: context.ink),
                      ),
                      if (port.visits > 1) ...[
                        const SizedBox(width: 6),
                        Text(
                          '×${port.visits}',
                          style: NavisType.caption.copyWith(
                            color: context.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (rest > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    l.statsMorePorts(rest),
                    style: NavisType.bodySm.copyWith(
                      color: context.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
