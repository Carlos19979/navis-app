import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/boat/data/models/boat_model.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class BoatRepositoryImpl implements BoatRepository {
  BoatRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  static List<Boat>? _cachedBoats;

  @override
  Future<PaginatedResponse<Boat>> getBoats({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/boats',
        queryParameters: queryParams,
      );

      final envelope = response.data!;
      final items = (envelope['data'] as List<dynamic>)
          .map((json) =>
              BoatModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList();
      final meta = envelope['meta'] as Map<String, dynamic>?;

      if (cursor == null) {
        _cachedBoats = items;
      }

      return PaginatedResponse<Boat>(
        items: items,
        nextCursor: meta?['next_cursor'] as String?,
      );
    } catch (e) {
      if (_cachedBoats != null && cursor == null) {
        return PaginatedResponse<Boat>(
          items: _cachedBoats!,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Boat> getBoat(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/boats/$id',
    );
    final envelope = response.data!;
    return BoatModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  @override
  Future<Boat> createBoat(Boat boat) async {
    final model = BoatModel.fromEntity(boat);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats',
      data: model.toJson(),
    );
    final envelope = response.data!;
    return BoatModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  @override
  Future<Boat> updateBoat(Boat boat) async {
    final model = BoatModel.fromEntity(boat);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/${boat.id}',
      data: model.toJson(),
    );
    final envelope = response.data!;
    return BoatModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  @override
  Future<void> deleteBoat(String id) async {
    await _apiClient.delete<void>('/api/v1/boats/$id');
  }
}
