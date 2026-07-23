import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/core/config/env.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';

/// RevenueCat entitlement identifiers that unlock each paid tier. Must match the
/// entitlements configured in the RevenueCat dashboard and the backend webhook.
const plusEntitlementId = 'plus';
const proEntitlementId = 'pro';

/// The subscription tier ladder. `index` is the rank (free < plus < pro).
enum PlanTier {
  free,
  plus,
  pro;

  bool atLeast(PlanTier other) => index >= other.index;

  static PlanTier fromName(String? name) => switch (name) {
        'pro' => PlanTier.pro,
        'plus' => PlanTier.plus,
        _ => PlanTier.free,
      };

  // Capability rules — mirror of apps/api/internal/domain/profile.go.
  bool get canAnchorAlarm => atLeast(PlanTier.plus);
  bool get canMaintenanceSchedules => atLeast(PlanTier.plus);
  bool get canFullReadiness => atLeast(PlanTier.plus);
  bool get canCostAnalytics => this == PlanTier.pro;
  bool get canSharedCoordination => this == PlanTier.pro;
  bool get canExportPassport => this == PlanTier.pro;
  bool get canCreateGroups => this == PlanTier.pro;
  int get maxBoats => switch (this) {
        PlanTier.pro => 3,
        PlanTier.plus => 2,
        PlanTier.free => 1,
      };
  int get galleryLimit => atLeast(PlanTier.plus) ? 10 : 1;
  int get attachmentLimit => atLeast(PlanTier.plus) ? -1 : 1;
}

/// Thin wrapper around the RevenueCat SDK. This is the ONLY file that imports
/// `purchases_flutter`, so the rest of the app stays store-agnostic. Every call
/// degrades gracefully (no-op / false) when no API key is configured.
class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  bool _configured = false;

  String get _apiKey {
    if (Platform.isIOS || Platform.isMacOS) return Env.revenueCatIosKey;
    if (Platform.isAndroid) return Env.revenueCatAndroidKey;
    return '';
  }

  /// Whether in-app purchases are available (a platform API key is set).
  bool get isAvailable => _apiKey.isNotEmpty;

  /// Configures the SDK once. Safe to call unconditionally at startup.
  Future<void> configure() async {
    if (_configured || _apiKey.isEmpty) return;
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      _configured = true;
    } catch (_) {
      // Billing unavailable — app continues without purchases.
    }
  }

  /// Aligns the RevenueCat app-user-id with the Supabase user id so the webhook
  /// can map entitlements back to the right profile.
  Future<void> logIn(String userId) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  /// The highest tier currently active for the logged-in user.
  Future<PlanTier> activeTier() async {
    if (!_configured) return PlanTier.free;
    try {
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active;
      if (active.containsKey(proEntitlementId)) return PlanTier.pro;
      if (active.containsKey(plusEntitlementId)) return PlanTier.plus;
      return PlanTier.free;
    } catch (_) {
      return PlanTier.free;
    }
  }

  /// All purchasable packages from the current offering (empty if none). The
  /// paywall splits them per tier by product identifier (navis_plus_* /
  /// navis_pro_*).
  Future<List<Package>> allPackages() async {
    if (!_configured) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Purchases a package. Returns the active tier afterwards (free if the user
  /// cancelled). Re-checks entitlements so the result is independent of the
  /// SDK's purchase return shape.
  Future<PlanTier> purchase(Package package) async {
    if (!_configured) return PlanTier.free;
    try {
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PlanTier.free;
      }
      rethrow;
    }
    return activeTier();
  }

  /// The store page where the user manages (or cancels) their subscription.
  /// RevenueCat's managementURL points at the store the purchase was made in
  /// (App Store or Play Store); when unavailable we fall back to the current
  /// platform's generic subscriptions page.
  Future<Uri?> managementUrl() async {
    if (_configured) {
      try {
        final info = await Purchases.getCustomerInfo();
        final url = info.managementURL;
        if (url != null && url.isNotEmpty) return Uri.parse(url);
      } catch (_) {}
    }
    if (Platform.isAndroid) {
      return Uri.parse('https://play.google.com/store/account/subscriptions');
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return Uri.parse('https://apps.apple.com/account/subscriptions');
    }
    return null;
  }

  /// Restores previous purchases. Returns the active tier afterwards.
  Future<PlanTier> restore() async {
    if (!_configured) return PlanTier.free;
    try {
      await Purchases.restorePurchases();
    } catch (_) {
      return PlanTier.free;
    }
    return activeTier();
  }
}

final billingServiceProvider =
    Provider<BillingService>((ref) => BillingService.instance);

/// Client-side mirror of the live RevenueCat tier. Lets the UI unlock instantly
/// after a purchase, before the server webhook updates `profiles.plan`.
final liveTierProvider = StateProvider<PlanTier>((ref) => PlanTier.free);

/// The effective tier: the higher of the server account plan and the live RC
/// mirror. This is what the UI gates on (via its capability getters).
final effectiveTierProvider = Provider<PlanTier>((ref) {
  final account = ref.watch(accountProvider).valueOrNull;
  final serverTier = PlanTier.fromName(account?.plan);
  final live = ref.watch(liveTierProvider);
  return serverTier.index >= live.index ? serverTier : live;
});

/// Backward-compatible "is top tier" flag (Pro). Prefer gating on the specific
/// capability via [effectiveTierProvider] (e.g. `.canCostAnalytics`).
final isProProvider = Provider<bool>(
  (ref) => ref.watch(effectiveTierProvider) == PlanTier.pro,
);

/// Watches auth state and syncs the RevenueCat identity + live tier mirror.
/// Must be watched from the app root to stay active.
final billingAuthListenerProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);
  final billing = ref.read(billingServiceProvider);
  if (!billing.isAvailable) return;

  final user = authState.user;
  if (authState.status == AuthStatus.authenticated && user != null) {
    billing
        .logIn(user.id)
        .then((_) => billing.activeTier())
        .then((tier) => ref.read(liveTierProvider.notifier).state = tier);
  } else if (authState.status == AuthStatus.unauthenticated) {
    billing.logOut();
    ref.read(liveTierProvider.notifier).state = PlanTier.free;
  }
});
