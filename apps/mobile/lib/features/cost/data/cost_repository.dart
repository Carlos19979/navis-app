import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';

/// Spend attributed to one category (or "maintenance").
class CostBreakdownItem {
  const CostBreakdownItem({required this.key, required this.amount});

  factory CostBreakdownItem.fromJson(Map<String, dynamic> j) =>
      CostBreakdownItem(
        key: j['key'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );

  final String key;
  final double amount;
}

/// Total spend in a calendar month (month = "YYYY-MM").
class CostMonthly {
  const CostMonthly({required this.month, required this.amount});

  factory CostMonthly.fromJson(Map<String, dynamic> j) => CostMonthly(
        month: j['month'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );

  final String month;
  final double amount;
}

/// Advanced cost intelligence for a boat (Pro).
class CostAnalytics {
  const CostAnalytics({
    required this.totalSpend,
    required this.expenseSpend,
    required this.maintenanceSpend,
    required this.byCategory,
    required this.monthly,
    required this.totalDistanceNm,
    required this.completedTrips,
    required this.totalFuelL,
    required this.costPerNm,
    required this.costPerTrip,
    required this.fuelPerNm,
  });

  factory CostAnalytics.fromJson(Map<String, dynamic> j) => CostAnalytics(
        totalSpend: (j['total_spend'] as num?)?.toDouble() ?? 0,
        expenseSpend: (j['expense_spend'] as num?)?.toDouble() ?? 0,
        maintenanceSpend: (j['maintenance_spend'] as num?)?.toDouble() ?? 0,
        byCategory: ((j['by_category'] as List?) ?? [])
            .map((e) => CostBreakdownItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        monthly: ((j['monthly'] as List?) ?? [])
            .map((e) => CostMonthly.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalDistanceNm: (j['total_distance_nm'] as num?)?.toDouble() ?? 0,
        completedTrips: (j['completed_trips'] as num?)?.toInt() ?? 0,
        totalFuelL: (j['total_fuel_l'] as num?)?.toDouble() ?? 0,
        costPerNm: (j['cost_per_nm'] as num?)?.toDouble(),
        costPerTrip: (j['cost_per_trip'] as num?)?.toDouble(),
        fuelPerNm: (j['fuel_per_nm'] as num?)?.toDouble(),
      );

  final double totalSpend;
  final double expenseSpend;
  final double maintenanceSpend;
  final List<CostBreakdownItem> byCategory;
  final List<CostMonthly> monthly;
  final double totalDistanceNm;
  final int completedTrips;
  final double totalFuelL;
  final double? costPerNm;
  final double? costPerTrip;
  final double? fuelPerNm;
}

class CostRepository {
  CostRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<CostAnalytics> getForBoat(String boatId) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/cost-analytics');
    return CostAnalytics.fromJson(
        response.data!['data'] as Map<String, dynamic>);
  }
}

final costRepositoryProvider =
    Provider<CostRepository>((ref) => CostRepository());
