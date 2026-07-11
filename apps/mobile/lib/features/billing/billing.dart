import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/core/config/env.dart';
import 'package:navis_mobile/features/auth/domain/auth_state.dart';
import 'package:navis_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:navis_mobile/features/profile/data/account_provider.dart';

/// RevenueCat entitlement identifier that unlocks Navis Pro. Must match the
/// entitlement configured in the RevenueCat dashboard and the backend webhook.
const proEntitlementId = 'pro';

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

  /// Whether the Pro entitlement is currently active for the logged-in user.
  Future<bool> isProActive() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(proEntitlementId);
    } catch (_) {
      return false;
    }
  }

  /// The purchasable Pro packages from the current offering (empty if none).
  Future<List<Package>> proPackages() async {
    if (!_configured) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Purchases a package. Returns true if Pro is active afterwards, false if the
  /// user cancelled. Re-checks entitlement so the result is independent of the
  /// SDK's purchase return shape.
  Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    try {
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
    return isProActive();
  }

  /// Restores previous purchases. Returns whether Pro is active afterwards.
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      await Purchases.restorePurchases();
    } catch (_) {
      return false;
    }
    return isProActive();
  }
}

final billingServiceProvider =
    Provider<BillingService>((ref) => BillingService.instance);

/// Client-side mirror of the live RevenueCat Pro entitlement. Lets the UI unlock
/// instantly after a purchase, before the server webhook updates `profiles.plan`.
final proEntitlementProvider = StateProvider<bool>((ref) => false);

/// True when the user has Pro either per the server account or the live RC
/// entitlement. This is what the UI should gate on.
final isProProvider = Provider<bool>((ref) {
  final account = ref.watch(accountProvider).valueOrNull;
  final rc = ref.watch(proEntitlementProvider);
  return (account?.isPro ?? false) || rc;
});

/// Watches auth state and syncs the RevenueCat identity + entitlement mirror.
/// Must be watched from the app root to stay active.
final billingAuthListenerProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);
  final billing = ref.read(billingServiceProvider);
  if (!billing.isAvailable) return;

  final user = authState.user;
  if (authState.status == AuthStatus.authenticated && user != null) {
    billing
        .logIn(user.id)
        .then((_) => billing.isProActive())
        .then((pro) => ref.read(proEntitlementProvider.notifier).state = pro);
  } else if (authState.status == AuthStatus.unauthenticated) {
    billing.logOut();
    ref.read(proEntitlementProvider.notifier).state = false;
  }
});
