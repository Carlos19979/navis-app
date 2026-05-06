import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/database/offline_repository.dart';
import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/logbook/data/models/trip_model.dart';
import 'package:navis_mobile/features/logbook/domain/entities/trip.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class TripRepository {
  TripRepository({
    ApiClient? apiClient,
    this.offlineRepo,
    this.mutationQueue,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;
  final OfflineRepository? offlineRepo;
  final MutationQueueNotifier? mutationQueue;

  Future<PaginatedResponse<Trip>> getTrips(
    String boatId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/boats/$boatId/trips',
        queryParameters: queryParams,
      );

      final envelope = response.data!;
      final dataList = envelope['data'] as List<dynamic>;
      final items = dataList
          .map((json) =>
              TripModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();
      final meta = envelope['meta'] as Map<String, dynamic>?;

      if (cursor == null && offlineRepo != null) {
        await offlineRepo!.cacheList(
          'trips',
          dataList.cast<Map<String, dynamic>>(),
          boatId: boatId,
        );
      }

      return PaginatedResponse<Trip>(
        items: items,
        nextCursor: meta?['next_cursor'] as String?,
      );
    } catch (e) {
      if (offlineRepo != null &&
          cursor == null &&
          offlineRepo!.isNetworkError(e)) {
        final cached = await offlineRepo!.getCachedByBoat('trips', boatId);
        if (cached.isNotEmpty) {
          return PaginatedResponse<Trip>(
            items: cached.map((j) => TripModel.fromJson(j).toEntity()).toList(),
          );
        }
      }
      rethrow;
    }
  }

  Future<Trip> getTrip(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/trips/$id',
      );
      final envelope = response.data!;
      final data = envelope['data'] as Map<String, dynamic>;

      if (offlineRepo != null) {
        await offlineRepo!.cacheItem(
          'trips',
          id,
          data,
          boatId: data['boat_id'] as String?,
        );
      }

      final trip = TripModel.fromJson(data).toEntity();

      final trackPoints = await getTrackPoints(id);
      if (trackPoints.isNotEmpty) {
        return trip.copyWith(trackPoints: trackPoints);
      }
      return trip;
    } catch (e) {
      if (offlineRepo != null && offlineRepo!.isNetworkError(e)) {
        final cached = await offlineRepo!.getCachedById('trips', id);
        if (cached != null) {
          return TripModel.fromJson(cached).toEntity();
        }
      }
      rethrow;
    }
  }

  Future<List<TrackPoint>> getTrackPoints(
    String tripId, {
    double? simplify,
  }) async {
    final queryParams = <String, dynamic>{
      if (simplify != null) 'simplify': simplify,
    };
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/trips/$tripId/tracks',
      queryParameters: queryParams,
    );
    final envelope = response.data!;
    final data = envelope['data'] as List<dynamic>?;
    if (data == null) return [];
    return data
        .map((json) => TrackPointModel.fromJson(json as Map<String, dynamic>))
        .map((m) => TrackPoint(
              latitude: m.latitude,
              longitude: m.longitude,
              timestamp: m.timestamp,
              speedKnots: m.speedKnots,
            ))
        .toList();
  }

  Future<Trip> createTrip(Trip trip) async {
    final model = TripModel.fromEntity(trip);
    final json = model.toJson();
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/v1/boats/${trip.boatId}/trips',
        data: json,
      );
      final envelope = response.data!;
      return TripModel.fromJson(
        envelope['data'] as Map<String, dynamic>,
      ).toEntity();
    } catch (e) {
      if (_canEnqueue(e)) {
        await mutationQueue!.enqueue(
          method: 'POST',
          path: '/api/v1/boats/${trip.boatId}/trips',
          body: json,
        );
        return trip;
      }
      rethrow;
    }
  }

  Future<Trip> updateTrip(Trip trip) async {
    final model = TripModel.fromEntity(trip);
    final json = model.toJson();
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/api/v1/trips/${trip.id}',
        data: json,
      );
      final envelope = response.data!;
      return TripModel.fromJson(
        envelope['data'] as Map<String, dynamic>,
      ).toEntity();
    } catch (e) {
      if (_canEnqueue(e)) {
        await mutationQueue!.enqueue(
          method: 'PUT',
          path: '/api/v1/trips/${trip.id}',
          body: json,
        );
        return trip;
      }
      rethrow;
    }
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
    try {
      await _apiClient.delete<void>('/api/v1/trips/$id');
      if (offlineRepo != null) {
        await offlineRepo!.removeItem('trips', id);
      }
    } catch (e) {
      if (_canEnqueue(e)) {
        if (offlineRepo != null) {
          await offlineRepo!.removeItem('trips', id);
        }
        await mutationQueue!.enqueue(
          method: 'DELETE',
          path: '/api/v1/trips/$id',
        );
      } else {
        rethrow;
      }
    }
  }

  bool _canEnqueue(Object e) =>
      mutationQueue != null &&
      offlineRepo != null &&
      offlineRepo!.isNetworkError(e);
}
