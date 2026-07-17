@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';

import '../helpers/billing.dart';
import '../helpers/plan.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('paywall sheet — ${brightness.name}', (tester) async {
      final billing = MockBillingService();
      when(billing.proPackages).thenAnswer(
        (_) async => [
          makePackage(),
          makePackage(type: PackageType.annual, price: '39,99 €'),
        ],
      );

      // The paywall is a modal bottom sheet: pump a neutral host, open the
      // sheet via showPaywall (like the app does) and capture the whole
      // MaterialApp so the golden includes the sheet over its scrim.
      await pumpGolden(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPaywall(context, ref),
                child: const Text('open paywall'),
              ),
            ),
          ),
        ),
        brightness: brightness,
        settle: false,
        overrides: [
          ...planOverrides(),
          billingOverride(billing),
        ],
      );
      await tester.tap(find.text('open paywall'));
      await pumpGoldenFrames(tester);

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(goldenPath('paywall', brightness)),
      );
    });
  }
}
