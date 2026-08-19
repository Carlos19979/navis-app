import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navis_mobile/core/config/settings_service.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A fresh container over the same storage — the app being killed and
  /// relaunched, which is all it takes to lose anything held in memory.
  ProviderContainer restart() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('passwordRecoveryProvider', () {
    test('starts clean', () {
      expect(restart().read(passwordRecoveryProvider), isFalse);
    });

    // The bug this exists for: the recovery link hands the app a real session,
    // which supabase_flutter persists. When the pending-recovery flag lived in
    // memory, leaving the reset screen and reopening the app dropped the flag
    // while the session survived, so the app opened straight into the boat
    // list — logged in, password never changed.
    test('a pending recovery survives a restart', () {
      restart().read(passwordRecoveryProvider.notifier).begin();

      expect(restart().read(passwordRecoveryProvider), isTrue);
    });

    test('setting the new password ends it, for good', () {
      restart().read(passwordRecoveryProvider.notifier).begin();

      restart().read(passwordRecoveryProvider.notifier).complete();

      expect(restart().read(passwordRecoveryProvider), isFalse);
    });

    // Otherwise an abandoned recovery link would hijack every later login:
    // the flag outlives the app now, so something has to settle it.
    test('a recovery left half-done does not outlive a normal sign-in', () {
      restart().read(passwordRecoveryProvider.notifier).begin();

      // What AuthNotifier.login and .logout both call.
      restart().read(passwordRecoveryProvider.notifier).complete();

      expect(restart().read(passwordRecoveryProvider), isFalse);
    });

    test('begin is idempotent', () {
      final container = restart();
      container.read(passwordRecoveryProvider.notifier)
        ..begin()
        ..begin();

      expect(container.read(passwordRecoveryProvider), isTrue);
      expect(restart().read(passwordRecoveryProvider), isTrue);
    });
  });
}
