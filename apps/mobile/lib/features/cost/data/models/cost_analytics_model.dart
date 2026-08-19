import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';

/// JSON for one month of the cost series.
final class CostMonthModel {
  const CostMonthModel._();

  static CostMonth fromJson(Map<String, dynamic> json) => CostMonth(
        month: json['month'] as String? ?? '',
        byCategory: _amounts(json['by_category']),
        fixed: _num(json['fixed']),
        variable: _num(json['variable']),
        fuelAmount: _num(json['fuel_amount']),
        fuelLiters: _num(json['fuel_liters']),
        trips: (json['trips'] as num?)?.toInt() ?? 0,
        distanceNm: _num(json['distance_nm']),
        fuelL: _num(json['fuel_l']),
        engineHours: _num(json['engine_hours']),
        hours: _num(json['hours']),
      );

  static double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

  /// Category keys are open-ended — the owner can invent one — so the map is
  /// taken as it comes rather than matched against an enum.
  static Map<String, double> _amounts(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toDouble(),
    };
  }
}

/// JSON for the whole payload.
final class CostAnalyticsModel {
  const CostAnalyticsModel._();

  static CostAnalytics fromJson(Map<String, dynamic> json) => CostAnalytics(
        months: ((json['months'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CostMonthModel.fromJson)
            .toList(growable: false),
      );
}
