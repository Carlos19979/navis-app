import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/anomaly/data/anomaly_repository.dart';
import 'package:navis_mobile/features/cost/data/cost_repository.dart';
import 'package:navis_mobile/features/cost/presentation/providers/cost_provider.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';

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
        error: (e, _) => NavisErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(boatCostAnalyticsProvider(boatId)),
        ),
        data: (c) => ListView(
          padding: const EdgeInsets.all(Dimens.spaceLg),
          children: [
            _AnomaliesSection(boatId: boatId),
            Row(
              children: [
                _Kpi(
                  label: l.costTotalSpend,
                  value: _money(c.totalSpend),
                  color: AppColors.cyan,
                ),
                const SizedBox(width: Dimens.spaceSm),
                _Kpi(
                  label: l.costPerNmLabel,
                  value: c.costPerNm == null ? '—' : _money(c.costPerNm!),
                  color: AppColors.green,
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceSm),
            Row(
              children: [
                _Kpi(
                  label: l.costPerTripLabel,
                  value: c.costPerTrip == null ? '—' : _money(c.costPerTrip!),
                  color: AppColors.amber,
                ),
                const SizedBox(width: Dimens.spaceSm),
                _Kpi(
                  label: l.costFuelEfficiency,
                  value: c.fuelPerNm == null
                      ? '—'
                      : '${c.fuelPerNm!.toStringAsFixed(2)} L',
                  color: AppColors.cyan,
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceLg),
            if (c.byCategory.isNotEmpty) ...[
              _SectionTitle(l.costByCategory),
              const SizedBox(height: Dimens.spaceSm),
              _CategoryBreakdown(items: c.byCategory, total: c.totalSpend),
              const SizedBox(height: Dimens.spaceLg),
            ],
            _SectionTitle(l.costMonthlySpend),
            const SizedBox(height: Dimens.spaceSm),
            _MonthlyChart(monthly: c.monthly),
          ],
        ),
      ),
    );
  }
}

String _money(double v) => '${v.toStringAsFixed(0)} €';

/// Fuel-efficiency anomalies, shown only when there are any (Pro insight).
class _AnomaliesSection extends ConsumerWidget {
  const _AnomaliesSection({required this.boatId});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(boatAnomaliesProvider(boatId));
    final anomalies = async.valueOrNull ?? const <Anomaly>[];
    if (anomalies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l.anomaliesTitle),
        const SizedBox(height: Dimens.spaceSm),
        for (final a in anomalies)
          Padding(
            padding: const EdgeInsets.only(bottom: Dimens.spaceSm),
            child: NavisCard(
              borderColor: AppColors.amber.withValues(alpha: 0.4),
              child: Row(
                children: [
                  const Icon(Icons.local_gas_station_rounded,
                      color: AppColors.amber, size: 22),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Dimens.spaceLg),
      ],
    );
  }
}

String _categoryLabel(AppLocalizations l, String key) => switch (key) {
      'combustible' => l.expenseCategoryFuel,
      'amarre' => l.expenseCategoryMooring,
      'seguro' => l.expenseCategoryInsurance,
      'reparación' => l.expenseCategoryRepair, // i18n-exempt: API value
      'limpieza' => l.expenseCategoryCleaning,
      'otros' => l.expenseCategoryOther,
      'maintenance' => l.readinessCatMaintenance,
      _ => key,
    };

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: NavisCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: context.txtSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: context.txtPrimary,
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.items, required this.total});

  final List<CostBreakdownItem> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NavisCard(
      child: Column(
        children: [
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _categoryLabel(l, item.key),
                          style: TextStyle(
                            fontSize: 14,
                            color: context.txtPrimary,
                          ),
                        ),
                      ),
                      Text(
                        _money(item.amount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.txtPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? (item.amount / total) : 0,
                      minHeight: 6,
                      backgroundColor: context.glassBg,
                      valueColor: const AlwaysStoppedAnimation(AppColors.cyan),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.monthly});

  final List<CostMonthly> monthly;

  @override
  Widget build(BuildContext context) {
    final maxAmount = monthly.fold<double>(
      1,
      (m, e) => e.amount > m ? e.amount : m,
    );
    return NavisCard(
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final m in monthly)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: (m.amount / maxAmount * 80).clamp(2.0, 80.0),
                        decoration: BoxDecoration(
                          gradient:
                              m.amount > 0 ? AppColors.cyanGradient : null,
                          color: m.amount > 0
                              ? null
                              : context.txtSecondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          m.month.substring(5), // "MM"
                          style: TextStyle(
                            fontSize: 9,
                            color: context.txtSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
