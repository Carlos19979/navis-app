import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/network/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Firebase is deliberately NOT initialized here: this reproduces a device
  // without GoogleService-Info.plist / google-services.json, where
  // FirebaseMessaging.instance throws [core/no-app]. The service must
  // degrade to no-ops instead of breaking the auth flow that constructs it.
  group('NotificationService without Firebase configured', () {
    test('construction does not throw', () {
      expect(NotificationService.new, returnsNormally);
    });

    test('getToken returns null', () async {
      expect(await NotificationService().getToken(), isNull);
    });

    test('requestPermission completes', () async {
      await expectLater(
        NotificationService().requestPermission(),
        completes,
      );
    });

    test('registerDevice and unregisterDevice complete (no token → no-op)',
        () async {
      final service = NotificationService();
      await expectLater(service.registerDevice(), completes);
      await expectLater(service.unregisterDevice(), completes);
    });

    test('onTokenRefresh does not throw', () {
      expect(
        () => NotificationService().onTokenRefresh((_) {}),
        returnsNormally,
      );
    });
  });
}
