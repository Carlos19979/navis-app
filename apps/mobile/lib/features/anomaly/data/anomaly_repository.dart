import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';

/// A trip flagged for anomalous fuel efficiency.
class Anomaly {
  const Anomaly({
    required this.tripId,
    required this.date,
    required this.metric,
    required this.value,
    required this.baseline,
    required this.deviationPct,
  });

  factory Anomaly.fromJson(Map<String, dynamic> j) => Anomaly(
        tripId: j['trip_id'] as String? ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        metric: j['metric'] as String? ?? '',
        value: (j['value'] as num?)?.toDouble() ?? 0,
        baseline: (j['baseline'] as num?)?.toDouble() ?? 0,
        deviationPct: (j['deviation_pct'] as num?)?.toDouble() ?? 0,
      );

  final String tripId;
  final DateTime date;
  final String metric;
  final double value;
  final double baseline;
  final double deviationPct;
}

class AnomalyRepository {
  AnomalyRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Anomaly>> forBoat(String boatId) async {
    final res = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/anomalies');
    final data = (res.data!['data'] as List?) ?? [];
    return data
        .map((e) => Anomaly.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final anomalyRepositoryProvider =
    Provider<AnomalyRepository>((ref) => AnomalyRepository());

/// Fuel-efficiency anomalies for a boat. autoDispose so it refetches on revisit.
final boatAnomaliesProvider =
    FutureProvider.autoDispose.family<List<Anomaly>, String>((ref, boatId) {
  return ref.watch(anomalyRepositoryProvider).forBoat(boatId);
});
