import 'package:navis_mobile/core/network/notification_service.dart';

/// No-op NotificationService. The real one constructs
/// `FirebaseMessaging.instance` in a field initializer, which throws
/// [core/no-app] when Firebase isn't configured (no GoogleService-Info.plist
/// on the simulator) — `implements` skips that initializer entirely.
class FakeNotificationService implements NotificationService {
  @override
  Future<void> requestPermission() async {}

  @override
  Future<String?> getToken() async => null;

  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> unregisterDevice() async {}

  @override
  void onTokenRefresh(void Function(String token) callback) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
