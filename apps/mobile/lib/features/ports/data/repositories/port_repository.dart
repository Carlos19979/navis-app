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

  /// Fetches ports whose location falls inside the geographic bounding box.
  /// Hits the PUBLIC `/ports?bbox=...` endpoint (no `/api/v1` prefix, no JWT
  /// required). Returns the page plus the opaque next cursor (null when the
  /// box is fully loaded).
  Future<({List<Port> ports, String? nextCursor})> getWithinBBox({
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
    String? cursor,
    int limit = 50,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/ports',
      queryParameters: {
        'bbox': '$minLon,$minLat,$maxLon,$maxLat',
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );

    final envelope = response.data!;
    final dataList = envelope['data'] as List<dynamic>;
    final ports = dataList
        .map((json) =>
            PortModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();
    final meta = envelope['meta'] as Map<String, dynamic>?;
    return (ports: ports, nextCursor: meta?['next_cursor'] as String?);
  }

  /// Searches ports by name via the PUBLIC `/ports?q=...` endpoint. When a
  /// [nearLat]/[nearLon] reference is given, results come back ordered by
  /// distance to it (server-side), which is what the port pickers use.
  Future<List<Port>> searchPorts({
    required String query,
    double? nearLat,
    double? nearLon,
    int limit = 50,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/ports',
      queryParameters: {
        'q': query,
        if (nearLat != null && nearLon != null) 'near': '$nearLat,$nearLon',
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
