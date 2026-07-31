import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';

/// JSON model for the notification feed (`GET /api/v1/notifications`).
final class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    this.linkType,
    this.linkId,
    this.readAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String,
      category: json['category'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      linkType: json['link_type'] as String?,
      linkId: json['link_id'] as String?,
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  final String id;
  final String? category;
  final String title;
  final String body;
  final String? linkType;
  final String? linkId;
  final String? readAt;
  final String createdAt;

  AppNotification toEntity() {
    return AppNotification(
      id: id,
      category: NotificationCategory.tryParse(category),
      title: title,
      body: body,
      linkType: linkType,
      linkId: linkId,
      readAt: readAt == null ? null : DateTime.parse(readAt!).toLocal(),
      createdAt: DateTime.parse(createdAt).toLocal(),
    );
  }
}

/// JSON model for one entry of `GET|PUT /api/v1/me/notification-preferences`.
final class NotificationPreferenceModel {
  const NotificationPreferenceModel({
    required this.category,
    required this.enabled,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      category: json['category'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  factory NotificationPreferenceModel.fromEntity(NotificationPreference p) {
    return NotificationPreferenceModel(
      category: p.category.wire,
      enabled: p.enabled,
    );
  }

  final String category;
  final bool enabled;

  Map<String, dynamic> toJson() => {'category': category, 'enabled': enabled};

  /// Returns null for a category this build does not know, so an older app
  /// simply ignores a newer server's extra toggles instead of crashing.
  NotificationPreference? toEntity() {
    final parsed = NotificationCategory.tryParse(category);
    if (parsed == null) return null;
    return NotificationPreference(category: parsed, enabled: enabled);
  }
}
