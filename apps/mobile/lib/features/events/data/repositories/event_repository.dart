import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/events/data/models/event_model.dart';
import 'package:navis_mobile/features/events/domain/entities/event.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class EventRepository {
  EventRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<PaginatedResponse<Event>> getEvents({
    String? cursor,
    int limit = 20,
    bool upcomingOnly = true,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
      'upcoming': upcomingOnly,
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/events',
      queryParameters: queryParams,
    );

    final data = response.data!;
    final items = (data['items'] as List<dynamic>)
        .map((json) =>
            EventModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();

    return PaginatedResponse<Event>(
      items: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<Event> getEvent(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/events/$id',
    );
    return EventModel.fromJson(response.data!).toEntity();
  }

  Future<void> registerForEvent(String eventId) async {
    await _apiClient.post<void>(
      '/api/v1/events/$eventId/register',
    );
  }

  Future<void> unregisterFromEvent(String eventId) async {
    await _apiClient.delete<void>(
      '/api/v1/events/$eventId/register',
    );
  }
}
