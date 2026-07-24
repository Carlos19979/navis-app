@Tags(['golden'])
library;

// One-off: renders the real paywall at 3x device pixel ratio (~1170x2532) so
// the PNG meets Apple's App Store IAP "review screenshot" minimum size. The
// regular paywall golden (golden_harness pins DPR 1.0 → 390x844) is too small
// for App Store Connect. Regenerate with:
//   flutter test --update-goldens --tags golden test/golden/paywall_review_test.dart
// Output: test/golden/goldens/paywall_review.png

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/core/theme/app_theme.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

import '../helpers/billing.dart';
import '../helpers/plan.dart';
import 'golden_harness.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('paywall review screenshot (hi-res)', (tester) async {
    const logical = Size(390, 844);
    const dpr = 3.0;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = logical * dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final billing = MockBillingService();
    when(billing.allPackages).thenAnswer(
      (_) async => [
        makePackage(),
        makePackage(type: PackageType.annual, price: '39,99 €'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...planOverrides(),
          billingOverride(billing),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPaywall(context, ref),
                  child: const Text('open paywall'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpGoldenFrames(tester);
    await tester.tap(find.text('open paywall'));
    await pumpGoldenFrames(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/paywall_review.png'),
    );
  });
}
