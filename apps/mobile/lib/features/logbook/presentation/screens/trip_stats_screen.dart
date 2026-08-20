import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
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
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_period_picker.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_metric.dart';

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
          NavisMetric(
            icon: Icons.route_rounded,
            value: stats.trips.toString(),
            label: l.totalTrips,
            color: AppColors.cyan,
          ),
          NavisMetric(
            icon: Icons.anchor_rounded,
            value: stats.portCount.toString(),
            label: l.portsVisited,
            color: AppColors.cyan,
          ),
          NavisMetric(
            icon: Icons.speed_rounded,
            value: _knots(stats.topSpeedKn),
            label: l.topSpeed,
            color: AppColors.red,
          ),
          NavisMetric(
            icon: Icons.trending_up_rounded,
            value: stats.avgSpeedKn == null ? '—' : _knots(stats.avgSpeedKn!),
            label: l.averageSpeed,
            color: AppColors.green,
          ),
          NavisMetric(
            icon: Icons.local_gas_station_rounded,
            value:
                stats.fuelL > 0 ? '${stats.fuelL.toStringAsFixed(0)} L' : '—',
            label: l.fuelConsumed,
            color: AppColors.amber,
          ),
          NavisMetric(
            icon: Icons.engineering_rounded,
            value: stats.engineHours > 0
                ? '${stats.engineHours.toStringAsFixed(1)} h'
                : '—',
            label: l.totalEngineHours,
            color: AppColors.amber,
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

  static String _knots(double value) =>
      value > 0 ? '${value.toStringAsFixed(1)} kn' : '—';

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
    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _periodLabel(context, l, period),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.txtSecondary,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stats.distanceNm.toStringAsFixed(1),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.cyan,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'NM',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.cyan.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.statsHoursAndTrips(
              stats.hours.toStringAsFixed(1),
              stats.trips,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.txtSecondary,
                ),
          ),
        ],
      ),
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
    final rows = <(IconData, String, String)>[
      if (stats.avgTripNm != null)
        (
          Icons.straighten_rounded,
          l.statsAvgTrip,
          '${stats.avgTripNm!.toStringAsFixed(1)} NM',
        ),
      if (stats.longestTripNm > 0)
        (
          Icons.flag_rounded,
          l.statsLongestTrip,
          '${stats.longestTripNm.toStringAsFixed(1)} NM',
        ),
      if (stats.litresPerNm != null)
        (
          Icons.opacity_rounded,
          l.statsLitresPerNm,
          '${stats.litresPerNm!.toStringAsFixed(2)} L/NM',
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return NavisCard(
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0)
              Divider(
                  height: 18, color: context.glassBorderColor, thickness: 0.5),
            Row(
              children: [
                Icon(row.$1, size: 18, color: AppColors.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.$2,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.txtSecondary,
                        ),
                  ),
                ),
                Text(
                  row.$3,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
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

    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.portsVisited,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final port in shown)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.glassBg,
                    borderRadius: BorderRadius.circular(Dimens.radiusMd),
                    border: Border.all(
                      color: context.glassBorderColor,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        port.port,
                        style: TextStyle(
                          color: context.txtPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (port.visits > 1) ...[
                        const SizedBox(width: 6),
                        Text(
                          '×${port.visits}',
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
                    style: TextStyle(color: context.txtSecondary, fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
