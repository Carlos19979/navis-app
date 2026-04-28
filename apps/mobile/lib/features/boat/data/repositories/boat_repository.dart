import 'package:navis_mobile/core/database/offline_repository.dart';
import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/boat/data/models/boat_model.dart';
import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/features/boat/domain/repositories/boat_repository.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class BoatRepositoryImpl implements BoatRepository {
  BoatRepositoryImpl({
    ApiClient? apiClient,
    this.offlineRepo,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;
  final OfflineRepository? offlineRepo;

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
      final dataList = envelope['data'] as List<dynamic>;
      final items = dataList
          .map((json) =>
              BoatModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();
      final meta = envelope['meta'] as Map<String, dynamic>?;

      if (cursor == null && offlineRepo != null) {
        await offlineRepo!.cacheList(
          'boats',
          dataList.cast<Map<String, dynamic>>(),
        );
      }

      return PaginatedResponse<Boat>(
        items: items,
        nextCursor: meta?['next_cursor'] as String?,
      );
    } catch (e) {
      if (offlineRepo != null &&
          cursor == null &&
          offlineRepo!.isNetworkError(e)) {
        final cached = await offlineRepo!.getCachedList('boats');
        if (cached.isNotEmpty) {
          return PaginatedResponse<Boat>(
            items:
                cached.map((j) => BoatModel.fromJson(j).toEntity()).toList(),
          );
        }
      }
      rethrow;
    }
  }

  @override
  Future<Boat> getBoat(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/boats/$id',
      );
      final envelope = response.data!;
      final data = envelope['data'] as Map<String, dynamic>;

      if (offlineRepo != null) {
        await offlineRepo!.cacheItem('boats', id, data);
      }

      return BoatModel.fromJson(data).toEntity();
    } catch (e) {
      if (offlineRepo != null && offlineRepo!.isNetworkError(e)) {
        final cached = await offlineRepo!.getCachedById('boats', id);
        if (cached != null) {
          return BoatModel.fromJson(cached).toEntity();
        }
      }
      rethrow;
    }
  }

  @override
  Future<Boat> createBoat(Boat boat) async {
    final model = BoatModel.fromEntity(boat);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats',
      data: model.toJson(),
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;

    if (offlineRepo != null) {
      await offlineRepo!.cacheItem('boats', data['id'] as String, data);
    }

    return BoatModel.fromJson(data).toEntity();
  }

  @override
  Future<Boat> updateBoat(Boat boat) async {
    final model = BoatModel.fromEntity(boat);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/boats/${boat.id}',
      data: model.toJson(),
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;

    if (offlineRepo != null) {
      await offlineRepo!.cacheItem('boats', boat.id, data);
    }

    return BoatModel.fromJson(data).toEntity();
  }

  @override
  Future<void> deleteBoat(String id) async {
    await _apiClient.delete<void>('/api/v1/boats/$id');

    if (offlineRepo != null) {
      await offlineRepo!.removeItem('boats', id);
    }
  }
}
