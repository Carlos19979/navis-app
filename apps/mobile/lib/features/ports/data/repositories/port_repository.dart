import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/ports/data/models/port_model.dart';
import 'package:navis_mobile/features/ports/domain/entities/port.dart';

class PortRepository {
  PortRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Port>> getNearby({
    required double lat,
    required double lon,
    double radiusKm = 50,
    int limit = 50,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/ports/nearby',
      queryParameters: {
        'lat': lat,
        'lon': lon,
        'radius_km': radiusKm,
        'limit': limit,
      },
    );

    final envelope = response.data!;
    final dataList = envelope['data'] as List<dynamic>;
    return dataList
        .map((json) =>
            PortModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();
  }

  Future<Port> getById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/ports/$id',
    );

    final envelope = response.data!;
    return PortModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }
}
