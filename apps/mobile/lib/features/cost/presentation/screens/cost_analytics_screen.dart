import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:navis_mobile/app/routes.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/money_utils.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/cost/domain/cost_period_stats.dart';
import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/features/cost/presentation/widgets/cost_sections.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/models/analytics_period.dart';
import 'package:navis_mobile/shared/widgets/navis_bar_chart.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_period_picker.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_section.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_metric.dart';

/// What the boat costs, for whatever period the owner picks.
///
/// The previous version answered one question badly: a single "total spend" that
/// silently meant every record ever, next to a €/NM that divided that lifetime
/// total by a lifetime of miles. Everything is now computed for the selected
/// period, from a month series fetched once — so the chips cost no round trip —
/// and the headline always shows the sources it is made of.
class CostAnalyticsScreen extends ConsumerWidget {
  const CostAnalyticsScreen({super.key, required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(boatCostAnalyticsProvider(boatId));

    return NavisScaffold(
      title: l.costTitle,
      showBack: true,
      body: async.when(
        loading: () => const NavisShimmer(itemHeight: 96),
        // The exception is never shown: a Dio message is not something an owner
        // can act on, and the house rule is a clear message plus a retry.
        error: (_, __) => NavisErrorWidget(
          message: l.costLoadError,
          onRetry: () => ref.invalidate(boatCostAnalyticsProvider(boatId)),
        ),
        data: (analytics) => analytics.isEmpty
            ? _EmptyCosts(boatId: boatId)
            : _CostBody(boatId: boatId, analytics: analytics),
      ),
    );
  }
}

/// No expense, no maintenance cost, no renewal: there is nothing to slice. The
/// old screen showed `0 €` and three dashes here.
class _EmptyCosts extends StatelessWidget {
  const _EmptyCosts({required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NavisEmptyState(
      icon: Icons.savings_outlined,
      message: l.costEmptyMessage,
      description: l.costEmptyDescription,
      actionLabel: l.costEmptyAction,
      onAction: () => context.push(Routes.boatExpenses(boatId)),
    );
  }
}

class _CostBody extends ConsumerWidget {
  const _CostBody({required this.boatId, required this.analytics});

  final String boatId;
  final CostAnalytics analytics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final years = yearsWithCosts(analytics);
    var period = ref.watch(costPeriodProvider);

    // A year can disappear from under the selection when the list reloads.
    if (period.year != null && !years.contains(period.year)) {
      period = const AnalyticsPeriod.allTime();
    }
    final stats = costStatsFor(analytics, period);

    void select(AnalyticsPeriod next) =>
        ref.read(costPeriodProvider.notifier).state = next;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spaceLg,
        Dimens.spaceMd,
        Dimens.spaceLg,
        Dimens.spaceXxl,
      ),
      children: [
        NavisPeriodPicker(
          period: period,
          years: years,
          monthsWithData: period.year == null
              ? const {}
              : monthsWithCosts(analytics, period.year!),
          onChanged: select,
        ),
        const SizedBox(height: Dimens.spaceLg),
        CostHeadlineCard(period: period, stats: stats, locale: locale),
        if (!stats.hasAnyData) ...[
          const SizedBox(height: Dimens.spaceMd),
          NavisCard(
            child: Text(
              l.costNoSpendInPeriod,
              style: TextStyle(color: context.txtSecondary),
            ),
          ),
        ],
        if (stats.monthlyRunRate != null) ...[
          const SizedBox(height: Dimens.spaceMd),
          CostRunRateCard(stats: stats, locale: locale),
        ],
        if (stats.hasAnyData) ...[
          const SizedBox(height: Dimens.spaceMd),
          _RatioGrid(stats: stats, locale: locale),
        ],
        if (stats.hasSpend) ...[
          const SizedBox(height: Dimens.spaceMd),
          CostFixedVariableCard(stats: stats, locale: locale),
          NavisSectionHeader(
            label: l.costByCategory,
            trailing: TextButton(
              onPressed: () => context.push(Routes.boatExpenses(boatId)),
              child: Text(l.costViewExpenses),
            ),
          ),
          CostCategoryCard(stats: stats, locale: locale),
        ],
        // A single month has no trend of its own — the chart is the way back up
        // to the year.
        if (period.month == null) ...[
          NavisSectionHeader(label: l.costTrend),
          _TrendChart(
            analytics: analytics,
            period: period,
            locale: locale,
            onSelect: select,
          ),
        ],
        _Anomalies(
            boatId: boatId, period: period, stats: stats, locale: locale),
      ],
    );
  }
}

/// The per-unit figures. Each is `—` when its denominator is missing, rather
/// than a confident zero.
class _RatioGrid extends StatelessWidget {
  const _RatioGrid({required this.stats, required this.locale});

  final CostPeriodStats stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    String money(double? value) =>
        value == null ? '—' : Money.format(locale, value);

    return NavisMetricGrid(
      children: [
        NavisMetric(
          icon: Icons.straighten_rounded,
          value: money(stats.costPerNm),
          label: l.costPerNmLabel,
          color: context.accent,
        ),
        NavisMetric(
          icon: Icons.route_rounded,
          value: money(stats.costPerTrip),
          label: l.costPerTripLabel,
          color: context.positive,
        ),
        NavisMetric(
          icon: Icons.engineering_rounded,
          value: money(stats.costPerEngineHour),
          label: l.costPerEngineHourLabel,
          color: context.caution,
        ),
        NavisMetric(
          icon: Icons.opacity_rounded,
          value: stats.litresPerNm == null
              ? '—'
              : '${stats.litresPerNm!.toStringAsFixed(2)} L/NM',
          label: l.costFuelEfficiency,
          color: context.accent,
        ),
        NavisMetric(
          icon: Icons.local_gas_station_rounded,
          value: stats.pricePerLiter == null
              ? '—'
              : Money.perUnit(locale, stats.pricePerLiter!, 'L', precise: true),
          label: l.costAvgPricePerLiter,
          color: context.caution,
        ),
        NavisMetric(
          icon: Icons.water_drop_outlined,
          value: stats.fuelLiters > 0
              ? '${stats.fuelLiters.toStringAsFixed(0)} L'
              : '—',
          label: l.costLitersPurchased,
          color: context.positive,
        ),
      ],
    );
  }
}

/// Spend over time: one bar per year when looking at everything, one per month
/// inside a year. Tapping a bar drills in, which is also how the month filter is
/// discovered.
class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.analytics,
    required this.period,
    required this.locale,
    required this.onSelect,
  });

  final CostAnalytics analytics;
  final AnalyticsPeriod period;
  final String locale;
  final ValueChanged<AnalyticsPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final bars = period.isAllTime
        ? _yearBars(context)
        : _monthBars(context, period.year!);
    if (bars.isEmpty) return const SizedBox.shrink();

    final withValue = bars.where((b) => b.value > 0).toList();
    final average = withValue.isEmpty
        ? null
        : withValue.fold<double>(0, (sum, b) => sum + b.value) /
            withValue.length;

    return NavisBarChart(
      bars: bars,
      averageValue: average,
      averageLabel: average == null
          ? null
          : l.costTrendAverage(Money.format(locale, average)),
    );
  }

  List<NavisBar> _yearBars(BuildContext context) {
    final byYear = <int, double>{};
    for (final month in analytics.months) {
      byYear[month.year] = (byYear[month.year] ?? 0) + month.total;
    }
    final years = byYear.keys.toList()..sort();
    return [
      for (final year in years)
        NavisBar(
          label: '$year',
          value: byYear[year]!,
          valueLabel: Money.format(locale, byYear[year]!),
          onTap: () => onSelect(AnalyticsPeriod.year(year)),
        ),
    ];
  }

  List<NavisBar> _monthBars(BuildContext context, int year) {
    final names = navisShortMonthNames(context);
    final byMonth = <int, double>{};
    for (final month in analytics.months) {
      if (month.year != year) continue;
      final index = int.tryParse(month.month.split('-').last);
      if (index != null) byMonth[index] = month.total;
    }
    return [
      for (var m = 1; m <= 12; m++)
        if (byMonth.containsKey(m))
          NavisBar(
            label: names[m - 1],
            value: byMonth[m]!,
            valueLabel: Money.format(locale, byMonth[m]!),
            semanticsLabel: '${names[m - 1]} $year: '
                '${Money.format(locale, byMonth[m]!)}',
            onTap: () => onSelect(AnalyticsPeriod.month(year, m)),
          ),
    ];
  }
}

/// Fuel-efficiency anomalies of the period, priced. Shown only when there are
/// any (a Free plan gets a 402, which stays invisible here).
class _Anomalies extends ConsumerWidget {
  const _Anomalies({
    required this.boatId,
    required this.period,
    required this.stats,
    required this.locale,
  });

  /// Enough to see a pattern without turning the card into a list screen.
  static const _maxShown = 5;

  final String boatId;
  final AnalyticsPeriod period;
  final CostPeriodStats stats;
  final String locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final all = ref.watch(boatAnomaliesProvider(boatId)).valueOrNull ??
        const <Anomaly>[];
    final anomalies = all
        .where((a) => period.contains(a.date))
        .take(_maxShown)
        .toList(growable: false);
    if (anomalies.isEmpty) return const SizedBox.shrink();

    final pricePerLiter = stats.pricePerLiter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavisSectionHeader(label: l.anomaliesTitle, color: context.caution),
        for (final a in anomalies)
          Padding(
            padding: const EdgeInsets.only(bottom: Dimens.spaceSm),
            child: NavisCard(
              borderColor: context.caution.withValues(alpha: 0.4),
              onTap: a.tripId.isEmpty
                  ? null
                  : () => context.push(Routes.trip(a.tripId)),
              child: Row(
                children: [
                  Icon(
                    Icons.local_gas_station_rounded,
                    color: context.caution,
                    size: Dimens.iconMd,
                  ),
                  const SizedBox(width: Dimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.anomalyFuelHigh(a.deviationPct.round()),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                        Text(
                          NavisDateUtils.formatDate(a.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.txtSecondary,
                          ),
                        ),
                        // The litres are only money once there is a €/L to
                        // price them with, which needs a fuel expense that
                        // recorded its quantity.
                        if (pricePerLiter != null && a.excessLiters > 0)
                          Text(
                            l.anomalyExcessCost(
                              Money.format(
                                locale,
                                a.excessLiters * pricePerLiter,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.caution,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: Dimens.iconSm,
                    color: context.txtSecondary,
                  ),
                ],
              ),
            ),
          ),
        Text(
          l.anomaliesExplainer,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.txtSecondary),
        ),
      ],
    );
  }
}
