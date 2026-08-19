import 'package:flutter/foundation.dart';

/// The synthetic category keys the API adds alongside the owner's expense
/// categories. Spelled the way the API spells them.
abstract final class CostCategory {
  static const maintenance = 'maintenance';
  static const documents = 'documents';
  static const fuel = 'combustible';
}

/// Everything spent and sailed in one calendar month.
///
/// Money and use travel together so any period's ratios (€/NM, €/trip,
/// €/engine hour, L/NM, €/L) can be derived from a slice of the series without
/// another request — which is what makes the period control instant.
@immutable
final class CostMonth {
  const CostMonth({
    required this.month,
    required this.byCategory,
    required this.fixed,
    required this.variable,
    this.fuelAmount = 0,
    this.fuelLiters = 0,
    this.trips = 0,
    this.distanceNm = 0,
    this.fuelL = 0,
    this.engineHours = 0,
    this.hours = 0,
  });

  /// `YYYY-MM`.
  final String month;

  /// Expense categories plus [CostCategory.maintenance] and
  /// [CostCategory.documents].
  final Map<String, double> byCategory;

  /// Berth, insurance and paperwork renewals — owed whether the boat sails.
  final double fixed;

  /// Fuel, repairs, maintenance and anything else that scales with use.
  final double variable;

  /// Spend and litres across fuel expenses that recorded a quantity — the pair
  /// that yields a real blended €/L.
  final double fuelAmount;
  final double fuelLiters;

  /// Completed trips departing in the month, and what they logged.
  final int trips;
  final double distanceNm;
  final double fuelL;
  final double engineHours;
  final double hours;

  double get total => fixed + variable;

  int get year => int.tryParse(month.split('-').first) ?? 0;

  @override
  bool operator ==(Object other) =>
      other is CostMonth &&
      other.month == month &&
      other.fixed == fixed &&
      other.variable == variable &&
      other.fuelAmount == fuelAmount &&
      other.fuelLiters == fuelLiters &&
      other.trips == trips &&
      other.distanceNm == distanceNm &&
      other.fuelL == fuelL &&
      other.engineHours == engineHours &&
      other.hours == hours &&
      mapEquals(other.byCategory, byCategory);

  @override
  int get hashCode => Object.hash(
        month,
        fixed,
        variable,
        fuelAmount,
        fuelLiters,
        trips,
        distanceNm,
        fuelL,
        engineHours,
        hours,
        Object.hashAllUnordered(
            byCategory.entries.map((e) => (e.key, e.value))),
      );
}

/// Advanced cost intelligence for a boat (Pro): the whole month-by-month
/// history, chronological and zero-filled.
@immutable
final class CostAnalytics {
  const CostAnalytics({required this.months});

  static const empty = CostAnalytics(months: []);

  /// Oldest first, one entry per calendar month with no gaps.
  final List<CostMonth> months;

  bool get isEmpty => months.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is CostAnalytics && listEquals(other.months, months);

  @override
  int get hashCode => Object.hashAll(months);
}
