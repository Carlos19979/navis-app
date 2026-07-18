import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';

import '../../helpers/plan.dart';

void main() {
  group('effectiveTierProvider', () {
    test('free account and no live tier → free', () {
      final c = ProviderContainer(overrides: [
        accountProvider
            .overrideWith((ref) async => accountForTier(PlanTier.free)),
        liveTierProvider.overrideWith((ref) => PlanTier.free),
      ]);
      addTearDown(c.dispose);
      expect(c.read(effectiveTierProvider), PlanTier.free);
      expect(c.read(isProProvider), isFalse);
    });

    test('live tier unlocks instantly before the server catches up', () {
      final c = ProviderContainer(overrides: [
        accountProvider
            .overrideWith((ref) async => accountForTier(PlanTier.free)),
        liveTierProvider.overrideWith((ref) => PlanTier.pro),
      ]);
      addTearDown(c.dispose);
      // The live purchase mirror wins even while the account still says free.
      expect(c.read(effectiveTierProvider), PlanTier.pro);
      expect(c.read(isProProvider), isTrue);
    });

    test('server plan drives the tier once loaded', () async {
      final c = ProviderContainer(overrides: [
        accountProvider
            .overrideWith((ref) async => accountForTier(PlanTier.plus)),
        liveTierProvider.overrideWith((ref) => PlanTier.free),
      ]);
      addTearDown(c.dispose);

      expect(c.read(effectiveTierProvider), PlanTier.free); // still loading
      await c.read(accountProvider.future);
      expect(c.read(effectiveTierProvider), PlanTier.plus);
      // Plus is a paid tier but NOT Pro.
      expect(c.read(isProProvider), isFalse);
    });

    test('effective tier is the higher of server and live', () async {
      final c = ProviderContainer(overrides: [
        accountProvider
            .overrideWith((ref) async => accountForTier(PlanTier.pro)),
        liveTierProvider.overrideWith((ref) => PlanTier.plus),
      ]);
      addTearDown(c.dispose);
      await c.read(accountProvider.future);
      expect(c.read(effectiveTierProvider), PlanTier.pro);
    });
  });

  group('PlanTier capabilities', () {
    test('Plus unlocks the individual-owner bundle only', () {
      expect(PlanTier.plus.canAnchorAlarm, isTrue);
      expect(PlanTier.plus.canMaintenanceSchedules, isTrue);
      expect(PlanTier.plus.canFullReadiness, isTrue);
      expect(PlanTier.plus.canCostAnalytics, isFalse);
      expect(PlanTier.plus.canSharedCoordination, isFalse);
      expect(PlanTier.plus.canExportPassport, isFalse);
      expect(PlanTier.plus.maxBoats, 2);
    });

    test('Pro unlocks everything', () {
      expect(PlanTier.pro.canCostAnalytics, isTrue);
      expect(PlanTier.pro.canSharedCoordination, isTrue);
      expect(PlanTier.pro.canExportPassport, isTrue);
      expect(PlanTier.pro.canCreateGroups, isTrue);
      expect(PlanTier.pro.canAnchorAlarm, isTrue);
      expect(PlanTier.pro.maxBoats, 5);
    });

    test('Free unlocks nothing paid', () {
      expect(PlanTier.free.canAnchorAlarm, isFalse);
      expect(PlanTier.free.canFullReadiness, isFalse);
      expect(PlanTier.free.maxBoats, 1);
    });
  });
}
