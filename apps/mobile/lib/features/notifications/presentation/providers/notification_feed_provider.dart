import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/core/network/session_provider.dart';
import 'package:navis_mobile/features/notifications/data/repositories/notification_feed_repository.dart';
import 'package:navis_mobile/features/notifications/domain/entities/app_notification.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_feed_repository.dart';

final notificationFeedRepositoryProvider =
    Provider<NotificationFeedRepository>((ref) {
  return NotificationFeedRepositoryImpl(apiClient: ApiClient.instance);
});

/// The bell badge. Long-lived (the bell shows on every tab), so it watches the
/// session user: this count must never survive into the next account.
final unreadNotificationCountProvider =
    AsyncNotifierProvider<UnreadNotificationCountNotifier, int>(
  UnreadNotificationCountNotifier.new,
);

class UnreadNotificationCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    ref.watch(sessionUserIdProvider);
    return ref.watch(notificationFeedRepositoryProvider).getUnreadCount();
  }

  /// Re-reads the count. Used when a push lands while the app is in the
  /// foreground and after the feed marks things read.
  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// Drops the badge to zero without a round-trip (the feed already told the
  /// server). Keeps the bell honest while the mark-all request is in flight.
  void clear() => state = const AsyncData(0);

  /// Lowers the badge by one, never below zero.
  void decrement() {
    final current = state.valueOrNull;
    if (current == null || current <= 0) return;
    state = AsyncData(current - 1);
  }
}

/// The notification history behind the bell. Paginated, newest first.
final notificationFeedProvider =
    AsyncNotifierProvider<NotificationFeedNotifier, List<AppNotification>>(
  NotificationFeedNotifier.new,
);

class NotificationFeedNotifier extends AsyncNotifier<List<AppNotification>> {
  String? _nextCursor;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<AppNotification>> build() async {
    // User-scoped cache: rebuild when the signed-in user changes.
    ref.watch(sessionUserIdProvider);
    final repository = ref.watch(notificationFeedRepositoryProvider);
    final response = await repository.getNotifications();
    _nextCursor = response.nextCursor;
    _hasMore = response.nextCursor != null;
    _loadingMore = false;
    return response.items;
  }

  /// Appends the next page. Guarded against re-entry: the scroll listener fires
  /// on every scroll update near the end, which would otherwise send the same
  /// cursor several times and duplicate rows in the list.
  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final repository = ref.read(notificationFeedRepositoryProvider);
      final current = state.valueOrNull ?? [];
      final response = await repository.getNotifications(cursor: _nextCursor);
      _nextCursor = response.nextCursor;
      _hasMore = response.nextCursor != null;
      state = AsyncData([...current, ...response.items]);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Marks one notification as read, updating the list and the badge
  /// optimistically and reverting if the request fails.
  Future<void> markRead(String id) async {
    final current = state.valueOrNull ?? [];
    final target = current.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;

    state = AsyncData([
      for (final n in current)
        if (n.id == id) n.markedRead() else n,
    ]);
    ref.read(unreadNotificationCountProvider.notifier).decrement();

    try {
      await ref.read(notificationFeedRepositoryProvider).markRead(id);
    } catch (_) {
      state = AsyncData(current);
      await ref.read(unreadNotificationCountProvider.notifier).refresh();
      rethrow;
    }
  }

  /// Marks everything as read (the "mark all read" action).
  Future<void> markAllRead() async {
    final current = state.valueOrNull ?? [];
    if (current.every((n) => n.isRead)) return;

    final now = DateTime.now();
    state = AsyncData([for (final n in current) n.markedRead(now)]);
    ref.read(unreadNotificationCountProvider.notifier).clear();

    try {
      await ref.read(notificationFeedRepositoryProvider).markAllRead();
    } catch (_) {
      state = AsyncData(current);
      await ref.read(unreadNotificationCountProvider.notifier).refresh();
      rethrow;
    }
  }
}

/// The five per-category toggles (Settings → Notifications).
final notificationPreferencesProvider = AsyncNotifierProvider.autoDispose<
    NotificationPreferencesNotifier, List<NotificationPreference>>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier
    extends AutoDisposeAsyncNotifier<List<NotificationPreference>> {
  @override
  Future<List<NotificationPreference>> build() async {
    return ref.watch(notificationFeedRepositoryProvider).getPreferences();
  }

  /// Flips one category, sending the full set (the API replaces it). Optimistic
  /// so the switch responds immediately; reverts if the request fails.
  Future<void> toggle(NotificationCategory category, bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = [
      for (final p in current)
        if (p.category == category) p.copyWith(enabled: enabled) else p,
    ];
    state = AsyncData(updated);

    try {
      final saved = await ref
          .read(notificationFeedRepositoryProvider)
          .setPreferences(updated);
      state = AsyncData(saved);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}
