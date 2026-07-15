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
  /// Lazily resolved: `FirebaseMessaging.instance` itself throws
  /// [core/no-app] when Firebase.initializeApp() failed (no
  /// GoogleService-Info.plist / google-services.json), so it must not run
  /// in a field initializer — constructing this service would then break
  /// the auth listeners that read it. Null means push is unavailable.
  FirebaseMessaging? get _messaging {
    try {
      return FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('notifications: Firebase unavailable: $e');
      return null;
    }
  }

  /// Requests notification permission. Never throws: on a device without
  /// Firebase configured (or with Google services unavailable) notifications
  /// are simply skipped — they must not break login or startup.
  Future<void> requestPermission() async {
    try {
      await _messaging?.requestPermission();
    } catch (e) {
      debugPrint('notifications: requestPermission failed: $e');
    }
  }

  /// Returns the FCM token, or null when unavailable. Never throws.
  Future<String?> getToken() async {
    try {
      return await _messaging?.getToken();
    } catch (e) {
      debugPrint('notifications: getToken failed: $e');
      return null;
    }
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
    _messaging?.onTokenRefresh.listen(callback);
  }

  String _getPlatform() {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
