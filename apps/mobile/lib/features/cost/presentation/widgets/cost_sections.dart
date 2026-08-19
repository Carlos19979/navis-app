import 'package:flutter/material.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/chart_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/money_utils.dart';
import 'package:navis_mobile/features/cost/domain/cost_period_stats.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/models/analytics_period.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_period_picker.dart';

/// Localized label for a cost category key, as the API spells it. Categories the
/// owner invented fall through to their own text.
String costCategoryLabel(AppLocalizations l, String key) => switch (key) {
      'combustible' => l.expenseCategoryFuel,
      'amarre' => l.expenseCategoryMooring,
      'seguro' => l.expenseCategoryInsurance,
      'reparación' => l.expenseCategoryRepair, // i18n-exempt: API value
      'limpieza' => l.expenseCategoryCleaning,
      'otros' => l.expenseCategoryOther,
      'maintenance' => l.readinessCatMaintenance,
      'documents' => l.costBreakdownDocuments,
      _ => key,
    };

/// The headline: what the period cost, what it is made of, and how it compares.
///
/// The breakdown is never collapsed. "Total cost" used to be every record ever,
/// with nothing on screen to say so or to say which sources it summed — the two
/// things an owner needs before trusting the number.
class CostHeadlineCard extends StatelessWidget {
  const CostHeadlineCard({
    super.key,
    required this.period,
    required this.stats,
    required this.locale,
  });

  final AnalyticsPeriod period;
  final CostPeriodStats stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final delta = stats.deltaPct;
    final previous = period.previous;

    final sources = <(String, double)>[
      if (stats.expenses > 0) (l.costBreakdownExpenses, stats.expenses),
      if (stats.maintenance > 0)
        (l.costBreakdownMaintenance, stats.maintenance),
      if (stats.documents > 0) (l.costBreakdownDocuments, stats.documents),
    ];

    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.costTotalForPeriod} · '
                  '${navisPeriodLabel(context, l, period)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.txtSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (delta != null && previous != null)
                _DeltaBadge(
                  label: l.costVsPrevious(
                    Money.signedPercent(locale, delta),
                    navisPeriodLabel(context, l, previous),
                  ),
                  // More spend than before is the unwelcome direction.
                  worse: delta > 0,
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(locale, stats.total),
              maxLines: 1,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.cyan,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (stats.distanceNm > 0 || stats.trips > 0) ...[
            const SizedBox(height: 4),
            Text(
              l.costPeriodUsage(
                stats.distanceNm.toStringAsFixed(1),
                stats.trips,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.txtSecondary,
              ),
            ),
          ],
          if (sources.isNotEmpty) ...[
            Divider(
              height: Dimens.spaceXl,
              color: context.glassBorderColor,
              thickness: 0.5,
            ),
            for (final (index, source) in sources.indexed) ...[
              if (index > 0) const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      source.$1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.txtSecondary,
                      ),
                    ),
                  ),
                  Text(
                    Money.format(locale, source.$2),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.label, required this.worse});

  final String label;
  final bool worse;

  @override
  Widget build(BuildContext context) {
    final color = worse ? AppColors.amber : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Dimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            worse ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the boat costs per month and per year at the period's pace — the figure
/// an owner actually quotes, and the one the screen never showed.
class CostRunRateCard extends StatelessWidget {
  const CostRunRateCard({
    super.key,
    required this.stats,
    required this.locale,
  });

  final CostPeriodStats stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final monthly = stats.monthlyRunRate;
    final yearly = stats.projectedYear;
    if (monthly == null || yearly == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                size: Dimens.iconSm,
                color: AppColors.green,
              ),
              const SizedBox(width: Dimens.spaceSm),
              Text(
                l.costRunRateTitle,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spaceMd),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.costPerMonthValue(Money.format(locale, monthly)),
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Dimens.spaceSm),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    l.costPerYearValue(Money.format(locale, yearly)),
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: context.txtPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.costRunRateBasis(stats.recordedMonths),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.txtSecondary),
          ),
        ],
      ),
    );
  }
}

/// Fixed against variable spend, as one bar plus its two rows.
class CostFixedVariableCard extends StatelessWidget {
  const CostFixedVariableCard({
    super.key,
    required this.stats,
    required this.locale,
  });

  final CostPeriodStats stats;
  final String locale;

  static const _fixedColor = AppColors.cyan;
  static const _variableColor = AppColors.amber;

  static int _flex(double share) => (share * 1000).round().clamp(1, 1000);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fixedShare = stats.fixedShare;

    return NavisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.costFixedVsVariable,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Dimens.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              // stretch, not the default: a childless ColoredBox takes the
              // smallest constraint, so without a tight cross-axis height the
              // segments lay out 10 px wide and 0 px tall — an invisible bar.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (fixedShare > 0)
                    Expanded(
                      // At least one flex unit, so a sliver of a share still
                      // shows rather than rounding itself out of existence.
                      flex: _flex(fixedShare),
                      child: const ColoredBox(color: _fixedColor),
                    ),
                  if (fixedShare < 1)
                    Expanded(
                      flex: _flex(1 - fixedShare),
                      child: const ColoredBox(color: _variableColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dimens.spaceMd),
          _Row(
            color: _fixedColor,
            label: l.costFixed,
            amount: stats.fixed,
            share: fixedShare,
            locale: locale,
          ),
          const SizedBox(height: 6),
          _Row(
            color: _variableColor,
            label: l.costVariable,
            amount: stats.variable,
            share: 1 - fixedShare,
            locale: locale,
          ),
          const SizedBox(height: Dimens.spaceSm),
          Text(
            l.costFixedExplainer,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.txtSecondary),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.color,
    required this.label,
    required this.amount,
    required this.share,
    required this.locale,
  });

  final Color color;
  final String label;
  final double amount;
  final double share;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Dimens.spaceSm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: context.txtSecondary),
          ),
        ),
        Text(
          '${(share * 100).round()} %',
          style:
              theme.textTheme.bodySmall?.copyWith(color: context.txtSecondary),
        ),
        const SizedBox(width: Dimens.spaceMd),
        Text(
          Money.format(locale, amount),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.txtPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Spend per category, each with its own hue, its share, and how it moved
/// against the previous period.
class CostCategoryCard extends StatelessWidget {
  const CostCategoryCard({
    super.key,
    required this.stats,
    required this.locale,
  });

  final CostPeriodStats stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final total = stats.total;

    return NavisCard(
      child: Column(
        children: [
          for (final (index, item) in stats.byCategory.indexed) ...[
            if (index > 0) const SizedBox(height: Dimens.spaceMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: ChartColors.forCostCategory(item.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Dimens.spaceSm),
                    Expanded(
                      child: Text(
                        costCategoryLabel(l, item.key),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: context.txtPrimary),
                      ),
                    ),
                    if (item.deltaPct != null) ...[
                      Text(
                        Money.signedPercent(locale, item.deltaPct!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: item.deltaPct! > 0
                              ? AppColors.amber
                              : AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: Dimens.spaceSm),
                    ],
                    Text(
                      Money.format(locale, item.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.txtPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? (item.amount / total) : 0,
                    minHeight: 6,
                    backgroundColor: context.glassBg,
                    valueColor: AlwaysStoppedAnimation(
                      ChartColors.forCostCategory(item.key),
                    ),
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
