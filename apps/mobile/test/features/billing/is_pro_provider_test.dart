import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';

Account account({required bool isPro}) => Account(
      plan: isPro ? 'pro' : 'free',
      isPro: isPro,
      maxBoats: isPro ? 3 : 1,
      boatCount: 0,
      canCreateGroups: isPro,
      reminderDocLimit: isPro ? -1 : 1,
      maintenanceSchedules: isPro,
      attachmentLimit: isPro ? -1 : 1,
      galleryLimit: isPro ? 10 : 1,
      fullReadiness: isPro,
      costAnalytics: isPro,
      exportPassport: isPro,
      sharedCoordination: isPro,
      anomalyAlerts: isPro,
      anchorAlarm: isPro,
    );

void main() {
  group('isProProvider', () {
    test('free account and no RC entitlement → not Pro', () {
      final c = ProviderContainer(overrides: [
        accountProvider.overrideWith((ref) async => account(isPro: false)),
        proEntitlementProvider.overrideWith((ref) => false),
      ]);
      addTearDown(c.dispose);
      // account still loading (async) and no RC mirror → gated off.
      expect(c.read(isProProvider), isFalse);
    });

    test('RC entitlement unlocks Pro instantly before the server catches up',
        () {
      final c = ProviderContainer(overrides: [
        accountProvider.overrideWith((ref) async => account(isPro: false)),
        proEntitlementProvider.overrideWith((ref) => true),
      ]);
      addTearDown(c.dispose);
      // The live purchase mirror wins even while the account says free.
      expect(c.read(isProProvider), isTrue);
    });

    test('server account isPro unlocks Pro once loaded', () async {
      final c = ProviderContainer(overrides: [
        accountProvider.overrideWith((ref) async => account(isPro: true)),
        proEntitlementProvider.overrideWith((ref) => false),
      ]);
      addTearDown(c.dispose);

      expect(c.read(isProProvider), isFalse); // still loading
      await c.read(accountProvider.future);
      expect(c.read(isProProvider), isTrue); // loaded → Pro
    });
  });
}
