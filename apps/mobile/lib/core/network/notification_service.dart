import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/network/api_client.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Low-level FCM service for device token lifecycle.
///
/// Handles permission requests, token retrieval, and device
/// registration/unregistration with the Go API.
///
/// For higher-level notification orchestration (auth-aware init,
/// foreground/background handling, deep links), see
/// `NotificationNotifier` in the notifications feature.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  Future<void> registerDevice() async {
    final token = await getToken();
    if (token == null) return;

    try {
      await ApiClient.instance.post<void>(
        '/api/v1/devices',
        data: {'token': token, 'platform': _getPlatform()},
      );
    } catch (_) {
      // Silently fail — device registration is best-effort
    }
  }

  Future<void> unregisterDevice() async {
    final token = await getToken();
    if (token == null) return;

    try {
      await ApiClient.instance.delete<void>(
        '/api/v1/devices/$token',
      );
    } catch (_) {
      // Silently fail
    }
  }

  void onTokenRefresh(void Function(String token) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }

  String _getPlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
  }
}
