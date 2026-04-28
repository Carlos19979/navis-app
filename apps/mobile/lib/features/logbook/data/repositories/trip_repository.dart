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

    final envelope = response.data!;
    final items = (envelope['data'] as List<dynamic>)
        .map((json) =>
            TripModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();
    final meta = envelope['meta'] as Map<String, dynamic>?;

    return PaginatedResponse<Trip>(
      items: items,
      nextCursor: meta?['next_cursor'] as String?,
    );
  }

  Future<Trip> getTrip(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/trips/$id',
    );
    final envelope = response.data!;
    return TripModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<Trip> createTrip(Trip trip) async {
    final model = TripModel.fromEntity(trip);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/${trip.boatId}/trips',
      data: model.toJson(),
    );
    final envelope = response.data!;
    return TripModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<Trip> updateTrip(Trip trip) async {
    final model = TripModel.fromEntity(trip);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/trips/${trip.id}',
      data: model.toJson(),
    );
    final envelope = response.data!;
    return TripModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<Trip> completeTrip(
    String id, {
    String? arrivalPort,
    double? distanceNm,
    double? engineHours,
    double? fuelConsumedL,
  }) async {
    final data = <String, dynamic>{
      if (arrivalPort != null) 'arrival_port': arrivalPort,
      if (distanceNm != null) 'distance_nm': distanceNm,
      if (engineHours != null) 'engine_hours': engineHours,
      if (fuelConsumedL != null) 'fuel_consumed_l': fuelConsumedL,
    };
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/trips/$id/complete',
      data: data,
    );
    final envelope = response.data!;
    return TripModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  Future<void> addTrackPoints(
    String tripId,
    List<TrackPoint> points,
  ) async {
    final data = points
        .map((p) => {
              'lat': p.latitude,
              'lon': p.longitude,
              'recorded_at': p.timestamp.toIso8601String(),
              if (p.speedKnots != null) 'speed_knots': p.speedKnots,
            })
        .toList();
    await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/trips/$tripId/tracks',
      data: {'points': data},
    );
  }

  Future<void> deleteTrip(String id) async {
    await _apiClient.delete<void>('/api/v1/trips/$id');
  }
}
