import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:navis_mobile/features/billing/billing.dart';
import 'package:navis_mobile/features/billing/presentation/paywall_sheet.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';

import '../../helpers/helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(makePackage());
  });

  late MockBillingService billing;
  bool? result;

  setUp(() {
    billing = MockBillingService();
    result = null;
  });

  Widget buildHost({List<Override> overrides = const []}) {
    return buildTestApp(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showPaywall(context, ref);
              },
              child: const Text('open paywall'),
            ),
          ),
        ),
      ),
      overrides: [
        ...planOverrides(),
        billingOverride(billing),
        ...overrides,
      ],
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    setPhoneSize(tester);
    await tester.pumpWidget(buildHost());
    await tester.tap(find.text('open paywall'));
    await pumpScreen(tester);
  }

  /// The radio icon inside the package tile labelled [label].
  Finder tileRadio(String label, IconData icon) => find.descendant(
        of: find
            .ancestor(
              of: find.text(label),
              matching: find.byType(GestureDetector),
            )
            .first,
        matching: find.byIcon(icon),
      );

  group('PaywallSheet', () {
    testWidgets('shows a spinner while packages are loading', (tester) async {
      final completer = Completer<List<Package>>();
      when(() => billing.allPackages()).thenAnswer((_) => completer.future);

      await openSheet(tester);

      expectPaywall();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Restore purchases'), findsNothing);

      await drain(tester);
    });

    testWidgets('no offering shows unavailable text and no buy buttons',
        (tester) async {
      when(() => billing.allPackages()).thenAnswer((_) async => const []);

      await openSheet(tester);

      expectPaywall();
      expect(
        find.text('Subscriptions are not available right now. '
            'Try again later.'),
        findsOneWidget,
      );
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Restore purchases'), findsNothing);
    });

    testWidgets('renders package tiles with the first one pre-selected',
        (tester) async {
      when(() => billing.allPackages()).thenAnswer(
        (_) async => [
          makePackage(),
          makePackage(type: PackageType.annual, price: '39,99 €'),
        ],
      );

      await openSheet(tester);

      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('4,99 €'), findsOneWidget);
      expect(find.text('39,99 €'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);

      expect(
        tileRadio('Monthly', Icons.radio_button_checked_rounded),
        findsOneWidget,
      );
      expect(
        tileRadio('Yearly', Icons.radio_button_unchecked_rounded),
        findsOneWidget,
      );
    });

    testWidgets('tapping another tile moves the selection', (tester) async {
      when(() => billing.allPackages()).thenAnswer(
        (_) async => [
          makePackage(),
          makePackage(type: PackageType.annual, price: '39,99 €'),
        ],
      );

      await openSheet(tester);

      await tester.tap(find.text('Yearly'));
      await tester.pump();

      expect(
        tileRadio('Yearly', Icons.radio_button_checked_rounded),
        findsOneWidget,
      );
      expect(
        tileRadio('Monthly', Icons.radio_button_unchecked_rounded),
        findsOneWidget,
      );
    });

    testWidgets('successful purchase pops with true and shows welcome',
        (tester) async {
      when(() => billing.allPackages())
          .thenAnswer((_) async => [makePackage()]);
      when(() => billing.purchase(any())).thenAnswer((_) async => PlanTier.pro);

      await openSheet(tester);

      await tester.tap(find.text('Subscribe'));
      await pumpScreen(tester);

      expectPaywall(shown: false);
      expect(result, isTrue);
      expectSnackbar(tester, 'Welcome to Navis Pro!');

      await drain(tester);
    });

    testWidgets('cancelled purchase resets busy and keeps the sheet open',
        (tester) async {
      when(() => billing.allPackages())
          .thenAnswer((_) async => [makePackage()]);
      when(() => billing.purchase(any()))
          .thenAnswer((_) async => PlanTier.free);

      await openSheet(tester);

      await tester.tap(find.text('Subscribe'));
      await pumpScreen(tester);

      expectPaywall();
      expect(result, isNull);
      final button = tester.widget<NavisButton>(find.byType(NavisButton));
      expect(button.isLoading, isFalse);
      expect(find.text('Welcome to Navis Pro!'), findsNothing);
    });

    testWidgets('failed purchase shows the error snackbar', (tester) async {
      when(() => billing.allPackages())
          .thenAnswer((_) async => [makePackage()]);
      when(() => billing.purchase(any()))
          .thenThrow(Exception('store exploded'));

      await openSheet(tester);

      await tester.tap(find.text('Subscribe'));
      await pumpScreen(tester);

      expectPaywall();
      expect(result, isNull);
      expectSnackbar(tester, 'Could not complete the purchase.');

      await drain(tester);
    });

    testWidgets('successful restore unlocks Pro and pops with true',
        (tester) async {
      when(() => billing.allPackages())
          .thenAnswer((_) async => [makePackage()]);
      when(() => billing.restore()).thenAnswer((_) async => PlanTier.pro);

      await openSheet(tester);

      await tester.tap(find.text('Restore purchases'));
      await pumpScreen(tester);

      expectPaywall(shown: false);
      expect(result, isTrue);
      expectSnackbar(tester, 'Welcome to Navis Pro!');

      await drain(tester);
    });

    testWidgets('restore without purchases shows nothing-to-restore',
        (tester) async {
      when(() => billing.allPackages())
          .thenAnswer((_) async => [makePackage()]);
      when(() => billing.restore()).thenAnswer((_) async => PlanTier.free);

      await openSheet(tester);

      await tester.tap(find.text('Restore purchases'));
      await pumpScreen(tester);

      expectPaywall();
      expect(result, isNull);
      expectSnackbar(tester, 'No purchases to restore.');

      await drain(tester);
    });
  });
}
