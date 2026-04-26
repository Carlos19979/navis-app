import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/notifications/data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepositoryImpl>(
  (ref) => NotificationRepositoryImpl(apiClient: ApiClient.instance),
);

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(ref.watch(notificationRepositoryProvider)),
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
  NotificationNotifier(this._repository) : super(const NotificationState());

  final NotificationRepositoryImpl _repository;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

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

  void _onMessageTapped(RemoteMessage message) {
    // Deep link handling — extract document_id from payload
    // Navigation is handled by the widget tree listening to this provider
  }

  Future<void> unregister() async {
    final token = state.token;
    if (token != null) {
      try {
        await _repository.unregisterToken(token);
      } catch (_) {}
    }
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    state = const NotificationState();
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    super.dispose();
  }
}
