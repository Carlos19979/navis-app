import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/logbook/data/models/trip_model.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class TripRepository {
  TripRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<PaginatedResponse<Trip>> getTrips(
    String boatId, {
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/trips',
      queryParameters: queryParams,
    );

    final data = response.data!;
    final items = (data['items'] as List<dynamic>)
        .map((json) =>
            TripModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();

    return PaginatedResponse<Trip>(
      items: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<Trip> getTrip(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/trips/$id',
    );
    return TripModel.fromJson(response.data!).toEntity();
  }

  Future<Trip> createTrip(Trip trip) async {
    final model = TripModel.fromEntity(trip);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/${trip.boatId}/trips',
      data: model.toJson(),
    );
    return TripModel.fromJson(response.data!).toEntity();
  }

  Future<Trip> updateTrip(Trip trip) async {
    final model = TripModel.fromEntity(trip);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/trips/${trip.id}',
      data: model.toJson(),
    );
    return TripModel.fromJson(response.data!).toEntity();
  }

  Future<void> deleteTrip(String id) async {
    await _apiClient.delete<void>('/api/v1/trips/$id');
  }
}
