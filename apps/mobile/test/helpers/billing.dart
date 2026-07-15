import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/features/billing/billing.dart';

class MockBillingService extends Mock implements BillingService {}

class MockPackage extends Mock implements Package {}

class MockStoreProduct extends Mock implements StoreProduct {}

/// A stubbed RevenueCat [Package] with the getters the paywall reads.
Package makePackage({
  PackageType type = PackageType.monthly,
  String price = '4,99 €',
}) {
  final product = MockStoreProduct();
  when(() => product.identifier).thenReturn('navis_pro_${type.name}');
  when(() => product.title).thenReturn('Navis Pro');
  when(() => product.description).thenReturn('Navis Pro subscription');
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
