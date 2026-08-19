import 'package:flutter/foundation.dart';

import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';
import 'package:navis_mobile/shared/models/analytics_period.dart';

/// Spend attributed to one category in the period.
@immutable
final class CostCategoryTotal {
  const CostCategoryTotal({
    required this.key,
    required this.amount,
    required this.previousAmount,
  });

  final String key;
  final double amount;

  /// The same category in the comparable previous period, for the ▲/▼. Null
  /// when there is no previous period (all time) or it had no data.
  final double? previousAmount;

  /// Percent change against [previousAmount]; null when there is nothing to
  /// compare against. Growth from zero is not a percentage.
  double? get deltaPct => (previousAmount == null || previousAmount == 0)
      ? null
      : (amount / previousAmount! - 1) * 100;
}

/// Every figure the cost screen shows, for one period.
///
/// Pure arithmetic over the month series — no widgets, no providers — because
/// this is where the risk lives. The old screen had no period at all: its
/// "total spend" was every record ever, and €/NM divided a lifetime of spend by
/// a lifetime of miles.
@immutable
final class CostPeriodStats {
  const CostPeriodStats({
    required this.expenses,
    required this.maintenance,
    required this.documents,
    required this.fixed,
    required this.variable,
    required this.byCategory,
    required this.trips,
    required this.distanceNm,
    required this.fuelL,
    required this.engineHours,
    required this.hours,
    required this.fuelAmount,
    required this.fuelLiters,
    required this.recordedMonths,
    required this.previousTotal,
  });

  static const empty = CostPeriodStats(
    expenses: 0,
    maintenance: 0,
    documents: 0,
    fixed: 0,
    variable: 0,
    byCategory: [],
    trips: 0,
    distanceNm: 0,
    fuelL: 0,
    engineHours: 0,
    hours: 0,
    fuelAmount: 0,
    fuelLiters: 0,
    recordedMonths: 0,
    previousTotal: null,
  );

  /// The three sources the total is made of. Shown under the headline so the
  /// number can say what it is made of.
  final double expenses;
  final double maintenance;
  final double documents;

  final double fixed;
  final double variable;

  /// Biggest first.
  final List<CostCategoryTotal> byCategory;

  final int trips;
  final double distanceNm;
  final double fuelL;
  final double engineHours;
  final double hours;
  final double fuelAmount;
  final double fuelLiters;

  /// How many months of the period the boat has records for. The run-rate
  /// denominator: dividing by "months with spend" instead would inflate the
  /// figure for a boat that only spends in summer.
  final int recordedMonths;

  /// The comparable previous period's total; null for all time, which has
  /// nothing before it.
  final double? previousTotal;

  double get total => fixed + variable;

  bool get hasSpend => total > 0;
  bool get hasAnyData => total > 0 || trips > 0 || distanceNm > 0;

  /// Percent change against the previous period; null when there is no previous
  /// period or it was empty.
  double? get deltaPct => (previousTotal == null || previousTotal == 0)
      ? null
      : (total / previousTotal! - 1) * 100;

  double? get costPerNm => distanceNm > 0 ? total / distanceNm : null;
  double? get costPerTrip => trips > 0 ? total / trips : null;
  double? get costPerEngineHour => engineHours > 0 ? total / engineHours : null;
  double? get litresPerNm =>
      distanceNm > 0 && fuelL > 0 ? fuelL / distanceNm : null;
  double? get pricePerLiter => fuelLiters > 0 ? fuelAmount / fuelLiters : null;

  /// What the boat costs per month over the period. Null for a single month,
  /// where the total already *is* the monthly figure.
  double? get monthlyRunRate =>
      recordedMonths > 1 ? total / recordedMonths : null;

  /// The same rate annualised. Null whenever [monthlyRunRate] is.
  double? get projectedYear =>
      monthlyRunRate == null ? null : monthlyRunRate! * 12;

  double get fixedShare => total > 0 ? fixed / total : 0;
}

/// Aggregates the slice of [analytics] that [period] selects.
///
/// The series is already zero-filled to the current month by the API, so
/// counting its entries inside the period *is* the count of elapsed months —
/// no clock needed, and a year in progress divides by the months lived so far.
CostPeriodStats costStatsFor(CostAnalytics analytics, AnalyticsPeriod period) {
  final selected = analytics.months
      .where((m) => period.containsMonthKey(m.month))
      .toList(growable: false);
  if (selected.isEmpty) return CostPeriodStats.empty;

  final previous = period.previous;
  final previousMonths = previous == null
      ? const <CostMonth>[]
      : analytics.months
          .where((m) => previous.containsMonthKey(m.month))
          .toList(growable: false);

  final current = _sum(selected);
  final prior = _sum(previousMonths);

  final categories = current.byCategory.entries
      .map((e) => CostCategoryTotal(
            key: e.key,
            amount: e.value,
            previousAmount:
                previousMonths.isEmpty ? null : prior.byCategory[e.key] ?? 0,
          ))
      .toList()
    // Biggest first, then by key so equal amounts keep a stable order.
    ..sort((a, b) => a.amount == b.amount
        ? a.key.compareTo(b.key)
        : b.amount.compareTo(a.amount));

  return CostPeriodStats(
    expenses: current.expenses,
    maintenance: current.byCategory[CostCategory.maintenance] ?? 0,
    documents: current.byCategory[CostCategory.documents] ?? 0,
    fixed: current.fixed,
    variable: current.variable,
    byCategory: categories,
    trips: current.trips,
    distanceNm: current.distanceNm,
    fuelL: current.fuelL,
    engineHours: current.engineHours,
    hours: current.hours,
    fuelAmount: current.fuelAmount,
    fuelLiters: current.fuelLiters,
    recordedMonths: selected.length,
    previousTotal: previousMonths.isEmpty ? null : prior.fixed + prior.variable,
  );
}

/// The running totals of a set of months.
final class _Totals {
  final byCategory = <String, double>{};
  double fixed = 0;
  double variable = 0;
  double fuelAmount = 0;
  double fuelLiters = 0;
  int trips = 0;
  double distanceNm = 0;
  double fuelL = 0;
  double engineHours = 0;
  double hours = 0;

  /// Everything that is not maintenance or a document renewal — i.e. what the
  /// owner entered in the expenses ledger.
  double get expenses => byCategory.entries
      .where((e) =>
          e.key != CostCategory.maintenance && e.key != CostCategory.documents)
      .fold(0.0, (sum, e) => sum + e.value);
}

_Totals _sum(List<CostMonth> months) {
  final t = _Totals();
  for (final m in months) {
    for (final entry in m.byCategory.entries) {
      t.byCategory[entry.key] = (t.byCategory[entry.key] ?? 0) + entry.value;
    }
    t.fixed += m.fixed;
    t.variable += m.variable;
    t.fuelAmount += m.fuelAmount;
    t.fuelLiters += m.fuelLiters;
    t.trips += m.trips;
    t.distanceNm += m.distanceNm;
    t.fuelL += m.fuelL;
    t.engineHours += m.engineHours;
    t.hours += m.hours;
  }
  return t;
}

/// Years that have any cost or trip recorded, most recent first. What the year
/// filter offers — no empty years, and no guessing how far back records go.
List<int> yearsWithCosts(CostAnalytics analytics) {
  final years = {
    for (final m in analytics.months)
      if (_hasData(m)) m.year,
  }.toList()
    ..sort((a, b) => b.compareTo(a));
  return years;
}

/// Months (1-12) of [year] that have any cost or trip recorded.
Set<int> monthsWithCosts(CostAnalytics analytics, int year) => {
      for (final m in analytics.months)
        if (m.year == year && _hasData(m)) _monthNumber(m.month),
    };

bool _hasData(CostMonth m) => m.total > 0 || m.trips > 0;

int _monthNumber(String key) => int.tryParse(key.split('-').last) ?? 0;
