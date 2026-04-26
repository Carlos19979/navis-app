abstract class NotificationRepository {
  Future<void> initialize();
  Future<String?> getToken();
  Future<void> registerToken(String token, String platform);
  Future<void> unregisterToken(String token);
  Stream<String> get onTokenRefresh;
}
