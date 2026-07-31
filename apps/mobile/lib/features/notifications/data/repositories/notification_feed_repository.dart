import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/notifications/data/models/app_notification_model.dart';
import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_feed_repository.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

final class NotificationFeedRepositoryImpl
    implements NotificationFeedRepository {
  NotificationFeedRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<PaginatedResponse<AppNotification>> getNotifications({
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/notifications',
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );

    final envelope = response.data!;
    final items = (envelope['data'] as List<dynamic>)
        .map((json) =>
            AppNotificationModel.fromJson(json as Map<String, dynamic>)
                .toEntity())
        .toList();
    final meta = envelope['meta'] as Map<String, dynamic>?;

    return PaginatedResponse<AppNotification>(
      items: items,
      nextCursor: meta?['next_cursor'] as String?,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/notifications/unread-count',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    await _apiClient.put<void>('/api/v1/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _apiClient.put<void>('/api/v1/notifications/read-all');
  }

  @override
  Future<List<NotificationPreference>> getPreferences() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/me/notification-preferences',
    );
    return _parsePreferences(response.data!);
  }

  @override
  Future<List<NotificationPreference>> setPreferences(
    List<NotificationPreference> preferences,
  ) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/me/notification-preferences',
      data: {
        'categories': preferences
            .map((p) => NotificationPreferenceModel.fromEntity(p).toJson())
            .toList(),
      },
    );
    return _parsePreferences(response.data!);
  }

  List<NotificationPreference> _parsePreferences(
      Map<String, dynamic> envelope) {
    final data = envelope['data'] as Map<String, dynamic>;
    final categories = data['categories'] as List<dynamic>? ?? const [];
    return categories
        .map((json) => NotificationPreferenceModel.fromJson(
              json as Map<String, dynamic>,
            ).toEntity())
        .whereType<NotificationPreference>()
        .toList();
  }
}
