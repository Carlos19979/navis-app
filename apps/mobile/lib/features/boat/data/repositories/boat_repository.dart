import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/boat/data/models/boat_model.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class BoatRepositoryImpl implements BoatRepository {
  BoatRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  @override
  Future<PaginatedResponse<Boat>> getBoats({
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/boats',
      queryParameters: queryParams,
    );

    final data = response.data!;
    final items = (data['items'] as List<dynamic>)
        .map((json) => BoatModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();

    return PaginatedResponse<Boat>(
      items: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  @override
  Future<Boat> getBoat(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/boats/$id',
    );
    return BoatModel.fromJson(response.data!).toEntity();
  }

  @override
  Future<Boat> createBoat(Boat boat) async {
    final model = BoatModel.fromEntity(boat);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats',
      data: model.toJson(),
    );
    return BoatModel.fromJson(response.data!).toEntity();
  }

  @override
  Future<Boat> updateBoat(Boat boat) async {
    final model = BoatModel.fromEntity(boat);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/${boat.id}',
      data: model.toJson(),
    );
    return BoatModel.fromJson(response.data!).toEntity();
  }

  @override
  Future<void> deleteBoat(String id) async {
    await _apiClient.delete<void>('/api/v1/boats/$id');
  }
}
