import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/features/billing/billing.dart';

class MockBillingService extends Mock implements BillingService {}

class MockPackage extends Mock implements Package {}

class MockStoreProduct extends Mock implements StoreProduct {}

/// A stubbed RevenueCat [Package] with the getters the paywall reads.
///
/// [tier] drives the product identifier, which is how the paywall decides which
/// tier a package belongs to (`navis_plus_*` vs `navis_pro_*`).
Package makePackage({
  PackageType type = PackageType.monthly,
  String price = '4,99 €',
  PlanTier tier = PlanTier.pro,
}) {
  final name = tier == PlanTier.plus ? 'Plus' : 'Pro';
  final product = MockStoreProduct();
  when(() => product.identifier)
      .thenReturn('navis_${name.toLowerCase()}_${type.name}');
  when(() => product.title).thenReturn('Navis $name');
  when(() => product.description).thenReturn('Navis $name subscription');
  when(() => product.priceString).thenReturn(price);
  when(() => product.price).thenReturn(4.99);
  when(() => product.currencyCode).thenReturn('EUR');

  final package = MockPackage();
  when(() => package.identifier).thenReturn('\$rc_${type.name}');
  when(() => package.packageType).thenReturn(type);
  when(() => package.storeProduct).thenReturn(product);
  return package;
}

/// Overrides `billingServiceProvider` with [service].
Override billingOverride(BillingService service) =>
    billingServiceProvider.overrideWithValue(service);
