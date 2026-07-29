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
import 'package:navis_mobile/shared/widgets/gradient_background.dart';
import 'package:navis_mobile/shared/widgets/navis_app_bar.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

/// Abbreviated month names in the app's language.
///
/// The locale is passed explicitly: a bare `DateFormat.MMM()` follows
/// `Intl.defaultLocale`, which the app never sets, so the chart labelled its
/// months in English while the rest of the screen was in Spanish.
/// `flutter_localizations` has already registered the symbols for every locale.
List<String> _shortMonthNames(BuildContext context) =>
    DateFormat.MMM(Localizations.localeOf(context).languageCode)
        .dateSymbols
        .SHORTMONTHS;

/// Which slice of the logbook is on screen. Per boat, and reset when the screen
/// is left: coming back to "everything" is the useful default.
final _periodProvider = StateProvider.autoDispose<StatsPeriod>(
  (ref) => const StatsPeriod.allTime(),
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
      period = const StatsPeriod.allTime();
    }

    final selected = trips.where((t) => period.contains(t.departureTime));
    final stats = aggregateTrips(selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, Dimens.spaceXxl),
      children: [
        _PeriodPicker(
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
        _StatsGrid(children: [
          _StatCard(
            icon: Icons.route_rounded,
            value: stats.trips.toString(),
            label: l.totalTrips,
            color: AppColors.cyan,
          ),
          _StatCard(
            icon: Icons.anchor_rounded,
            value: stats.portCount.toString(),
            label: l.portsVisited,
            color: AppColors.cyan,
          ),
          _StatCard(
            icon: Icons.speed_rounded,
            value: _knots(stats.topSpeedKn),
            label: l.topSpeed,
            color: AppColors.red,
          ),
          _StatCard(
            icon: Icons.trending_up_rounded,
            value: stats.avgSpeedKn == null ? '—' : _knots(stats.avgSpeedKn!),
            label: l.averageSpeed,
            color: AppColors.green,
          ),
          _StatCard(
            icon: Icons.local_gas_station_rounded,
            value:
                stats.fuelL > 0 ? '${stats.fuelL.toStringAsFixed(0)} L' : '—',
            label: l.fuelConsumed,
            color: AppColors.amber,
          ),
          _StatCard(
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
          _MonthlyChart(
            countsByMonth: stats.tripsByMonth,
            year: period.year!,
            onMonthTap: (month) => ref.read(_periodProvider.notifier).state =
                StatsPeriod.month(period.year!, month),
          ),
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
}

/// Year row, plus a month row once a year is chosen. Only periods that have
/// trips are offered, so there is nothing to tap that leads to an empty screen.
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({
    required this.period,
    required this.years,
    required this.monthsWithData,
    required this.onChanged,
  });

  final StatsPeriod period;
  final List<int> years;
  final Set<int> monthsWithData;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final monthNames = _shortMonthNames(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _PeriodChip(
                label: l.allTime,
                selected: period.isAllTime,
                onTap: () => onChanged(const StatsPeriod.allTime()),
              ),
              for (final year in years) ...[
                const SizedBox(width: 8),
                _PeriodChip(
                  label: '$year',
                  selected: period.year == year,
                  onTap: () => onChanged(StatsPeriod.year(year)),
                ),
              ],
            ],
          ),
        ),
        if (period.year != null) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PeriodChip(
                  label: l.wholeYear,
                  selected: period.month == null,
                  onTap: () => onChanged(period.withMonth(null)),
                  compact: true,
                ),
                for (var month = 1; month <= 12; month++)
                  if (monthsWithData.contains(month)) ...[
                    const SizedBox(width: 6),
                    _PeriodChip(
                      label: monthNames[month - 1],
                      selected: period.month == month,
                      onTap: () => onChanged(period.withMonth(month)),
                      compact: true,
                    ),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dimens.radiusLg),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.cyan.withValues(alpha: 0.18)
                : context.glassBg,
            borderRadius: BorderRadius.circular(Dimens.radiusLg),
            border: Border.all(
              color: selected
                  ? AppColors.cyan.withValues(alpha: 0.55)
                  : context.glassBorderColor,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.cyan : context.txtSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Distance and time for the period, given the room they deserve: they are the
/// two numbers an owner actually quotes about a season.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.period, required this.stats});

  final StatsPeriod period;
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
    StatsPeriod period,
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 3) {
      final end = (i + 3).clamp(0, children.length);
      final slice = children.sublist(i, end);
      // No CrossAxisAlignment.stretch: inside a ListView the row's height is
      // unbounded and stretching asks children for an infinite height.
      rows.add(Row(
        children: [
          for (var j = 0; j < 3; j++) ...[
            if (j > 0) const SizedBox(width: 10),
            Expanded(
              child: j < slice.length ? slice[j] : const SizedBox.shrink(),
            ),
          ],
        ],
      ));
      if (end < children.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(children: rows);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NavisCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: Dimens.spaceSm),
          // Scale the value down to fit the card at large text sizes instead
          // of overriding the type scale with a fixed fontSize.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.txtSecondary,
                  fontSize: 10,
                ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Trips per month for the selected year. Tapping a bar drills into that month,
/// which is also the discoverable way into the month filter.
class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({
    required this.countsByMonth,
    required this.year,
    required this.onMonthTap,
  });

  final List<int> countsByMonth;
  final int year;
  final ValueChanged<int> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final maxCount =
        countsByMonth.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    final monthNames = _shortMonthNames(context);

    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.monthlyActivity,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final count = countsByMonth[i];
                final fraction = count / maxCount;
                return Expanded(
                  child: Semantics(
                    button: count > 0,
                    label: '${monthNames[i]} $year: $count',
                    child: InkWell(
                      onTap: count > 0 ? () => onMonthTap(i + 1) : null,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (count > 0)
                              Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Container(
                              height: (fraction * 60).clamp(4.0, 60.0),
                              decoration: BoxDecoration(
                                gradient:
                                    count > 0 ? AppColors.cyanGradient : null,
                                color: count > 0
                                    ? null
                                    : context.txtSecondary
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                monthNames[i],
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.txtSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
