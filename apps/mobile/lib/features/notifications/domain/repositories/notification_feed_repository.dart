import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

/// The in-app notification feed (the bell icon) and its per-category
/// preferences. Distinct from `NotificationRepository`, which owns the FCM
/// device-token lifecycle.
abstract class NotificationFeedRepository {
  Future<PaginatedResponse<AppNotification>> getNotifications({
    String? cursor,
    int limit,
  });

  /// Number of unread notifications — the bell badge.
  Future<int> getUnreadCount();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<List<NotificationPreference>> getPreferences();

  /// Replaces the user's preferences and returns the resulting state.
  Future<List<NotificationPreference>> setPreferences(
    List<NotificationPreference> preferences,
  );
}
