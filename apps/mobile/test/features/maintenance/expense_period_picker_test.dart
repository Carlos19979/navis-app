import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/maintenance/presentation/widgets/expense_period_picker.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

Widget wrap(Widget child, {Locale locale = const Locale('es')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('es')],
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('ExpensePeriod', () {
    test('a month period contains only dates in that month', () {
      const period = ExpensePeriod.month(2026, 7);

      expect(period.contains(DateTime(2026, 7)), isTrue);
      expect(period.contains(DateTime(2026, 7, 31)), isTrue);
      expect(period.contains(DateTime(2026, 6, 30)), isFalse);
      expect(period.contains(DateTime(2026, 8)), isFalse);
      expect(period.contains(DateTime(2025, 7, 15)), isFalse);
    });

    test('a whole-year period contains every month of that year', () {
      const period = ExpensePeriod.wholeYear(2026);

      expect(period.isWholeYear, isTrue);
      expect(period.contains(DateTime(2026)), isTrue);
      expect(period.contains(DateTime(2026, 12, 31)), isTrue);
      expect(period.contains(DateTime(2027)), isFalse);
    });

    test('current() opens on the month of the given date', () {
      final period = ExpensePeriod.current(DateTime(2026, 3, 9));

      expect(period, const ExpensePeriod.month(2026, 3));
      expect(period.start, DateTime(2026, 3));
    });

    test('equality is by year and month', () {
      expect(
        const ExpensePeriod.month(2026, 7),
        const ExpensePeriod.month(2026, 7),
      );
      expect(
        const ExpensePeriod.month(2026, 7),
        isNot(const ExpensePeriod.wholeYear(2026)),
      );
      expect(
        const ExpensePeriod.month(2026, 7).hashCode,
        const ExpensePeriod.month(2026, 7).hashCode,
      );
    });

    test('withMonth keeps the year', () {
      expect(
        const ExpensePeriod.wholeYear(2026).withMonth(4),
        const ExpensePeriod.month(2026, 4),
      );
    });
  });

  group('ExpensePeriodSelector label', () {
    testWidgets('formats the month in Spanish when the app is in Spanish',
        (tester) async {
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // The regression: DateFormat.yMMMM() with no locale printed "July 2026"
      // with the app in Spanish.
      expect(find.textContaining('July'), findsNothing);
      expect(find.textContaining('ulio de 2026'), findsOneWidget);
    });

    testWidgets('formats the month in English when the app is in English',
        (tester) async {
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (_) {},
        ),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('July 2026'), findsOneWidget);
    });

    testWidgets('shows the bare year for a whole-year period', (tester) async {
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.wholeYear(2026),
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOneWidget);
    });
  });

  group('period picker', () {
    testWidgets('tapping the selector opens the picker', (tester) async {
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(12));
    });

    testWidgets('picking a month reports the new period', (tester) async {
      ExpensePeriod? picked;
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (p) => picked = p,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();

      // Third chip is March, whatever the locale's abbreviation looks like.
      await tester.tap(find.byType(ChoiceChip).at(2));
      await tester.pumpAndSettle();

      expect(picked, const ExpensePeriod.month(2026, 3));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the year arrows move the grid a year at a time',
        (tester) async {
      ExpensePeriod? picked;
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (p) => picked = p,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);

      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();

      expect(picked, const ExpensePeriod.month(2025, 1));
    });

    testWidgets('whole year returns a year period', (tester) async {
      ExpensePeriod? picked;
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (p) => picked = p,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('es'));
      await tester.tap(find.text(l.expensesPeriodWholeYear));
      await tester.pumpAndSettle();

      expect(picked, const ExpensePeriod.wholeYear(2026));
    });

    testWidgets('dismissing changes nothing', (tester) async {
      var calls = 0;
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (_) => calls++,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();

      final l = await AppLocalizations.delegate.load(const Locale('es'));
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });

    testWidgets('re-picking the same month reports nothing', (tester) async {
      var calls = 0;
      await tester.pumpWidget(wrap(
        ExpensePeriodSelector(
          period: const ExpensePeriod.month(2026, 7),
          onChanged: (_) => calls++,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpensePeriodSelector));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ChoiceChip).at(6)); // July
      await tester.pumpAndSettle();

      expect(calls, 0);
    });
  });
}
