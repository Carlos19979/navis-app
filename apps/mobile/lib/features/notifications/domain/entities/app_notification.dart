/// The domain a notification belongs to. The wire values are the API's
/// notification categories (which are also the Novu workflow ids), and they are
/// the axis the user mutes: one preference toggle per category.
enum NotificationCategory {
  reminders('reminders'),
  regattaUpdates('regatta-updates'),
  groupUpdates('group-updates'),
  boatActivity('boat-activity'),
  eventLive('event-live');

  const NotificationCategory(this.wire);

  final String wire;

  /// Parses an API category, returning null for one this build does not know
  /// (a newer server may deliver categories an older app has never heard of).
  static NotificationCategory? tryParse(String? wire) {
    for (final category in NotificationCategory.values) {
      if (category.wire == wire) return category;
    }
    return null;
  }
}

/// One notification the API delivered to this user, stored server-side so the
/// history survives a push that never arrived.
final class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.linkType,
    this.linkId,
    this.readAt,
  });

  final String id;
  final NotificationCategory? category;
  final String title;
  final String body;

  /// Deep-link target for the tap (`{type, id}`), null when there is none.
  final String? linkType;
  final String? linkId;

  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  bool get hasLink => linkType != null && linkId != null && linkId!.isNotEmpty;

  AppNotification copyWith({
    String? id,
    NotificationCategory? category,
    String? title,
    String? body,
    String? linkType,
    String? linkId,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      body: body ?? this.body,
      linkType: linkType ?? this.linkType,
      linkId: linkId ?? this.linkId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Copy marked as read at [when] (defaults to now). Separate from [copyWith]
  /// because a null [readAt] there means "unchanged", so it cannot set one.
  AppNotification markedRead([DateTime? when]) {
    return AppNotification(
      id: id,
      category: category,
      title: title,
      body: body,
      linkType: linkType,
      linkId: linkId,
      readAt: readAt ?? when ?? DateTime.now(),
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification &&
        other.id == id &&
        other.category == category &&
        other.title == title &&
        other.body == body &&
        other.linkType == linkType &&
        other.linkId == linkId &&
        other.readAt == readAt &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        category,
        title,
        body,
        linkType,
        linkId,
        readAt,
        createdAt,
      );
}

/// Whether the user wants notifications of a given category.
final class NotificationPreference {
  const NotificationPreference({
    required this.category,
    required this.enabled,
  });

  final NotificationCategory category;
  final bool enabled;

  NotificationPreference copyWith({bool? enabled}) {
    return NotificationPreference(
      category: category,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreference &&
      other.category == category &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(category, enabled);
}
