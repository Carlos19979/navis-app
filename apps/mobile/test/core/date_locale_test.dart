import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/utils/navis_date_utils.dart';

/// The app formatted every date through `DateFormat` with no locale, and
/// nothing set `Intl.defaultLocale`, so dates came out in en_US ("28 Jul 2027",
/// "July 2026") with the app running in Spanish. The app root now applies the
/// locale MaterialApp resolved; these tests hold the behaviour that depends
/// on it.
void main() {
  final date = DateTime(2026, 7, 28, 14, 30);

  // In the app the symbols are registered by flutter_localizations when
  // Localizations loads its delegates, which happens before anything can format
  // a date. A bare unit test has no widget tree, so it registers them itself.
  setUpAll(initializeDateFormatting);

  setUp(() {
    // Global state: leave it as we found it for the rest of the run.
    final previous = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previous);
  });

  group('NavisDateUtils.useLocale', () {
    test('Spanish month names once the Spanish locale is applied', () {
      NavisDateUtils.useLocale(const Locale('es'));

      expect(NavisDateUtils.formatDate(date), contains('jul'));
      expect(NavisDateUtils.formatDate(date), isNot(contains('Jul')));
      expect(DateFormat.yMMMM().format(date), 'julio de 2026');
    });

    test('English month names for the English locale', () {
      NavisDateUtils.useLocale(const Locale('en'));

      expect(NavisDateUtils.formatDate(date), contains('Jul'));
      expect(DateFormat.yMMMM().format(date), 'July 2026');
    });

    test('a regional locale falls back to its language, not to English', () {
      // What a phone set to Spanish (Spain) resolves to.
      NavisDateUtils.useLocale(const Locale('es', 'ES'));

      expect(DateFormat.yMMMM().format(date), contains('julio'));
    });

    test('switching locale at runtime switches the formatting', () {
      NavisDateUtils.useLocale(const Locale('es'));
      final spanish = NavisDateUtils.formatDateTime(date);
      NavisDateUtils.useLocale(const Locale('en'));
      final english = NavisDateUtils.formatDateTime(date);

      expect(spanish, isNot(english));
      // The pattern is unchanged — only the month name is localized.
      expect(spanish, contains('14:30'));
      expect(english, contains('14:30'));
    });
  });

  // The wiring, not just the helper: an app built the way `NavisApp` builds it
  // must format dates in its own language.
  testWidgets('the app root applies its resolved locale to dates',
      (tester) async {
    Intl.defaultLocale = null;
    addTearDown(() => Intl.defaultLocale = null);
    String? rendered;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        // Same call, in the same place, as lib/app/app.dart.
        builder: (context, child) {
          NavisDateUtils.useLocale(Localizations.localeOf(context));
          return child ?? const SizedBox.shrink();
        },
        home: Builder(
          builder: (context) {
            rendered = NavisDateUtils.formatDate(date);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(rendered, isNotNull);
    expect(rendered, contains('jul'));
  });
}
