import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/notifications/data/repositories/notification_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Firebase is deliberately NOT initialized here: this reproduces a device
  // without GoogleService-Info.plist / google-services.json, where
  // FirebaseMessaging.instance throws [core/no-app]. Resolving it in a field
  // initializer used to blow up on construction and take the auth listener
  // that boots notifications on login down with it.
  group('NotificationRepositoryImpl without Firebase configured', () {
    NotificationRepositoryImpl build() =>
        NotificationRepositoryImpl(apiClient: ApiClient.instance);

    test('construction does not throw', () {
      expect(build, returnsNormally);
    });

    test('initialize completes', () async {
      await expectLater(build().initialize(), completes);
    });

    test('getToken returns null', () async {
      expect(await build().getToken(), isNull);
    });

    test('onTokenRefresh is an empty stream, not a throw', () async {
      expect(await build().onTokenRefresh.isEmpty, isTrue);
    });
  });
}
