import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';

/// Builds an [Account] with sensible defaults. Pro-only capabilities default
/// to the plan (`isPro`) unless overridden, mirroring `Account.fromJson`.
Account makeAccount({
  String plan = 'free',
  bool? isPro,
  int? maxBoats,
  int boatCount = 0,
  bool? canCreateGroups,
  int reminderDocLimit = 1,
  bool? maintenanceSchedules,
  int? attachmentLimit,
  int? galleryLimit,
  bool? fullReadiness,
  bool? costAnalytics,
  bool? exportPassport,
  bool? sharedCoordination,
  bool? anomalyAlerts,
}) {
  final pro = isPro ?? plan == 'pro';
  return Account(
    plan: plan,
    isPro: pro,
    maxBoats: maxBoats ?? (pro ? 3 : 1),
    boatCount: boatCount,
    canCreateGroups: canCreateGroups ?? pro,
    reminderDocLimit: reminderDocLimit,
    maintenanceSchedules: maintenanceSchedules ?? pro,
    attachmentLimit: attachmentLimit ?? (pro ? -1 : 1),
    galleryLimit: galleryLimit ?? (pro ? 10 : 1),
    fullReadiness: fullReadiness ?? pro,
    costAnalytics: costAnalytics ?? pro,
    exportPassport: exportPassport ?? pro,
    sharedCoordination: sharedCoordination ?? pro,
    anomalyAlerts: anomalyAlerts ?? pro,
  );
}

/// Overrides for plan gating: `accountProvider` (server entitlements) and
/// `proEntitlementProvider` (live RevenueCat mirror) together, so `isPro`
/// gates behave consistently.
List<Override> planOverrides({bool pro = false, Account? account}) {
  final resolved = account ?? makeAccount(plan: pro ? 'pro' : 'free');
  return [
    accountProvider.overrideWith((ref) async => resolved),
    proEntitlementProvider.overrideWith((ref) => resolved.isPro),
  ];
}

/// Asserts whether the Navis Pro paywall sheet is on screen.
void expectPaywall({bool shown = true}) {
  expect(
    find.text('Navis Pro'),
    shown ? findsOneWidget : findsNothing,
  );
}
