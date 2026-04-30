import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_repository.dart';

final class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  Future<void> initialize() async {
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<void> registerToken(
    String token,
    String platform,
  ) async {
    await _apiClient.post(
      '/api/v1/devices',
      data: {
        'token': token,
        'platform': platform,
      },
    );
  }

  @override
  Future<void> unregisterToken(String token) async {
    await _apiClient.delete('/api/v1/devices/$token');
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  static String get currentPlatform => Platform.isIOS ? 'ios' : 'android';
}
