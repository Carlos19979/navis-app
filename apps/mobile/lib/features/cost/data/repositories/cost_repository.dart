import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/cost/data/models/cost_analytics_model.dart';
import 'package:navis_mobile/features/cost/domain/entities/cost_analytics.dart';
import 'package:navis_mobile/features/cost/domain/repositories/cost_repository.dart';

final class CostRepositoryImpl implements CostRepository {
  CostRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  @override
  Future<CostAnalytics> getForBoat(String boatId) async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/boats/$boatId/cost-analytics');
    return CostAnalyticsModel.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }
}
