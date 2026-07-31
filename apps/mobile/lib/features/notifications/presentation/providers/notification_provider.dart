import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/notifications/data/repositories/notification_repository.dart';
import 'package:navis_mobile/features/notifications/presentation/providers/notification_feed_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepositoryImpl>(
  (ref) => NotificationRepositoryImpl(apiClient: ApiClient.instance),
);

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(ref.watch(notificationRepositoryProvider), ref),
);

class NotificationState {
  const NotificationState({
    this.token,
    this.isInitialized = false,
    this.permissionDenied = false,
  });

  final String? token;
  final bool isInitialized;
  final bool permissionDenied;
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier(this._repository, this._ref)
      : super(const NotificationState());

  final NotificationRepositoryImpl _repository;
  final Ref _ref;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  Future<void> initialize() async {
    if (state.isInitialized) return;

    await _repository.initialize();

    final token = await _repository.getToken();
    if (token == null) {
      state = const NotificationState(
        isInitialized: true,
        permissionDenied: true,
      );
      return;
    }

    await _repository.registerToken(
      token,
      NotificationRepositoryImpl.currentPlatform,
    );

    _tokenRefreshSub = _repository.onTokenRefresh.listen(_onTokenRefresh);
    _foregroundSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTapped);
    // A push that arrives while the app is open does not go through the tap
    // handler, so the bell badge would stay stale until the next launch.
    _messageSub = FirebaseMessaging.onMessage.listen((_) => _refreshFeed());

    state = NotificationState(token: token, isInitialized: true);
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final oldToken = state.token;
    if (oldToken != null && oldToken != newToken) {
      try {
        await _repository.unregisterToken(oldToken);
      } catch (_) {}
    }

    await _repository.registerToken(
      newToken,
      NotificationRepositoryImpl.currentPlatform,
    );
    state = NotificationState(token: newToken, isInitialized: true);
  }

  /// A tap means the notification was seen: bring the badge and the in-app feed
  /// in line. Navigation is deliberately NOT done here — `main.dart` owns it,
  /// because it is also the only handler alive on a cold start. Doing both
  /// pushed the target screen twice.
  void _onMessageTapped(RemoteMessage _) => _refreshFeed();

  /// Re-reads the badge and the notification list, which the server owns.
  void _refreshFeed() {
    _ref.read(unreadNotificationCountProvider.notifier).refresh();
    _ref.invalidate(notificationFeedProvider);
  }

  /// Routes a notification payload `{type, id}` to the matching screen via the
  /// root navigator. The Novu workflow must forward these as FCM data fields.
  Future<void> unregister() async {
    final token = state.token;
    if (token != null) {
      try {
        await _repository.unregisterToken(token);
      } catch (_) {}
    }
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _messageSub?.cancel();
    state = const NotificationState();
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _messageSub?.cancel();
    super.dispose();
  }
}
