import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';

Widget harness(void Function(BuildContext) onTap) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('es')],
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('NavisConfirmDialog', () {
    testWidgets('returns true when confirmed', (tester) async {
      bool? result;
      await tester.pumpWidget(harness((context) async {
        result = await NavisConfirmDialog.show(
          context,
          title: 'Delete',
          message: 'Sure?',
          confirmLabel: 'Delete',
          destructive: true,
        );
      }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Sure?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('returns false when cancelled', (tester) async {
      bool? result;
      await tester.pumpWidget(harness((context) async {
        result = await NavisConfirmDialog.show(
          context,
          title: 'Delete',
          message: 'Sure?',
          confirmLabel: 'Delete',
        );
      }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('NavisInputDialog', () {
    testWidgets('returns trimmed text, or null when empty', (tester) async {
      String? result = 'sentinel';
      await tester.pumpWidget(harness((context) async {
        result = await NavisInputDialog.show(
          context,
          title: 'Join',
          confirmLabel: 'Join',
          uppercase: true,
        );
      }));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  ABC123  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();
      expect(result, 'ABC123');
    });
  });
}
