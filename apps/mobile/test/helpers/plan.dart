import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';

/// Builds an [Account] whose capabilities match a subscription [tier], mirroring
/// the server (`profile.go`).
Account accountForTier(PlanTier tier) {
  final plus = tier.atLeast(PlanTier.plus);
  final pro = tier == PlanTier.pro;
  return Account(
    plan: tier.name,
    isPro: pro,
    maxBoats: tier.maxBoats,
    boatCount: 0,
    canCreateGroups: pro,
    reminderDocLimit: plus ? -1 : 1,
    maintenanceSchedules: plus,
    attachmentLimit: tier.attachmentLimit,
    galleryLimit: tier.galleryLimit,
    fullReadiness: plus,
    costAnalytics: pro,
    exportPassport: pro,
    sharedCoordination: pro,
    anomalyAlerts: pro,
    anchorAlarm: plus,
  );
}

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
  bool? anchorAlarm,
}) {
  final pro = isPro ?? plan == 'pro';
  return Account(
    plan: plan,
    isPro: pro,
    maxBoats: maxBoats ?? (pro ? 5 : 1),
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
    anchorAlarm: anchorAlarm ?? pro,
  );
}

/// Overrides for plan gating: `accountProvider` (server entitlements) and
/// `liveTierProvider` (live RevenueCat mirror) together, so tier gates behave
/// consistently. Pass [tier] for the 3-tier model, or the legacy [pro] bool.
List<Override> planOverrides({
  bool pro = false,
  PlanTier? tier,
  Account? account,
}) {
  final resolvedTier = tier ?? (pro ? PlanTier.pro : PlanTier.free);
  final resolved = account ?? accountForTier(resolvedTier);
  return [
    accountProvider.overrideWith((ref) async => resolved),
    liveTierProvider.overrideWith((ref) => PlanTier.fromName(resolved.plan)),
  ];
}

/// Asserts whether the Navis paywall sheet is on screen.
void expectPaywall({bool shown = true}) {
  expect(
    find.text('Navis Plus & Pro'),
    shown ? findsOneWidget : findsNothing,
  );
}
