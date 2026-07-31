import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/notifications/domain/repositories/notification_repository.dart';

final class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Lazily resolved: `FirebaseMessaging.instance` itself throws
  /// [core/no-app] when `Firebase.initializeApp()` failed (no
  /// GoogleService-Info.plist / google-services.json), so it must not run in a
  /// field initializer — constructing this repository would then break every
  /// consumer, including the auth listener that boots notifications on login.
  /// Null means push is unavailable; same contract as
  /// `core/network/notification_service.dart`.
  FirebaseMessaging? get _messaging {
    try {
      return FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('notifications: Firebase unavailable: $e');
      return null;
    }
  }

  /// Requests permission and enables foreground presentation. Never throws:
  /// with push unavailable it is a no-op, it must not break login or startup.
  @override
  Future<void> initialize() async {
    final messaging = _messaging;
    if (messaging == null) return;

    try {
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('notifications: initialize failed: $e');
    }
  }

  /// Returns the FCM token, or null when push is unavailable. Never throws.
  @override
  Future<String?> getToken() async {
    try {
      return await _messaging?.getToken();
    } catch (e) {
      debugPrint('notifications: getToken failed: $e');
      return null;
    }
  }

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

  /// Token rotations. An empty stream when push is unavailable, so callers can
  /// always `.listen()` without a null check.
  @override
  Stream<String> get onTokenRefresh =>
      _messaging?.onTokenRefresh ?? const Stream<String>.empty();

  static String get currentPlatform => Platform.isIOS ? 'ios' : 'android';
}
