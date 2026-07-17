// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/shared/presentation/screens/bookings_screen.dart';

import '../../helpers/helpers.dart';

class _MockSharedRepository extends Mock implements SharedRepository {}

void main() {
  setUpAll(() async {
    registerFallbackValue(FakeRoute());
    registerFallbackValue(DateTime(2026));
    // The screen resolves "who booked" against the Supabase session user
    // (the fake session signs in as user-1).
    await signInFakeUser();
  });

  const boatId = 'boat-1';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // A second day in the current month that is never today, so day-tap tests
  // work regardless of the date the suite runs on.
  final otherDay = today.day == 1
      ? DateTime(now.year, now.month, 2)
      : DateTime(now.year, now.month);

  Booking bookingOn(
    DateTime day, {
    String id = 'booking-1',
    String userId = 'user-1',
    String? purpose = 'Weekend sail',
    int startHour = 10,
    int endHour = 18,
  }) {
    return makeBooking(
      id: id,
      userId: userId,
      purpose: purpose,
      startsAt: DateTime(day.year, day.month, day.day, startHour),
      endsAt: DateTime(day.year, day.month, day.day, endHour),
    );
  }

  late _MockSharedRepository mockRepo;

  setUp(() {
    mockRepo = _MockSharedRepository();
  });

  Widget buildSubject({List<Booking> bookings = const []}) {
    return buildTestApp(
      const BookingsScreen(boatId: boatId),
      overrides: [
        sharedRepositoryProvider.overrideWithValue(mockRepo),
        boatBookingsProvider.overrideWith((ref, id) async => bookings),
        boatMembersProvider.overrideWith((ref, id) async => <BoatMember>[]),
      ],
    );
  }

  group('BookingsScreen calendar view', () {
    testWidgets('renders the current month by default', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(bookings: [bookingOn(today)]));
      await pumpScreen(tester);

      // Localized month title (test locale is en) and today's day cell.
      expect(
        find.text(DateFormat.yMMMM('en').format(today)),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('calendar-day-${today.day}')), findsOneWidget);
    });

    testWidgets('chevrons navigate to the previous and next month',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(bookings: [bookingOn(today)]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Next month'));
      await pumpScreen(tester);
      final nextMonth = DateTime(today.year, today.month + 1);
      expect(
        find.text(DateFormat.yMMMM('en').format(nextMonth)),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Previous month'));
      await pumpScreen(tester);
      expect(
        find.text(DateFormat.yMMMM('en').format(today)),
        findsOneWidget,
      );
    });

    testWidgets('dots mark days with bookings: cyan mine, secondary others',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(bookings: [
          bookingOn(today), // session user (user-1)
          bookingOn(otherDay, id: 'b-2', userId: 'user-2'),
        ]),
      );
      await pumpScreen(tester);

      expect(
        find.byKey(ValueKey('calendar-day-${today.day}-mine')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('calendar-day-${otherDay.day}-others')),
        findsOneWidget,
      );
      // No cross-marking: today has no others dot, the other day no mine dot.
      expect(
        find.byKey(ValueKey('calendar-day-${today.day}-others')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('calendar-day-${otherDay.day}-mine')),
        findsNothing,
      );
    });

    testWidgets('a day with two overlapping bookings gets the amber marker',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(bookings: [
          bookingOn(today, id: 'b-1', startHour: 9, endHour: 12),
          bookingOn(today, id: 'b-2', startHour: 11, endHour: 14),
          bookingOn(otherDay, id: 'b-3'),
        ]),
      );
      await pumpScreen(tester);

      expect(
        find.byKey(ValueKey('calendar-day-${today.day}-overlap')),
        findsOneWidget,
      );
      // A day with a single booking carries no overlap marker.
      expect(
        find.byKey(ValueKey('calendar-day-${otherDay.day}-overlap')),
        findsNothing,
      );
    });

    testWidgets('tapping a day filters the list below the calendar',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(bookings: [
          bookingOn(today, purpose: 'Sail today'),
          bookingOn(otherDay, id: 'b-2', purpose: 'Sail other day'),
        ]),
      );
      await pumpScreen(tester);

      // Today is selected by default.
      expect(find.textContaining('Sail today'), findsOneWidget);
      expect(find.textContaining('Sail other day'), findsNothing);

      await tester.tap(find.byKey(ValueKey('calendar-day-${otherDay.day}')));
      await pumpScreen(tester);

      expect(find.textContaining('Sail other day'), findsOneWidget);
      expect(find.textContaining('Sail today'), findsNothing);
    });

    testWidgets('a selected day without bookings shows the no-bookings note',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(bookings: [bookingOn(otherDay)]),
      );
      await pumpScreen(tester);

      // Today (selected by default) has no bookings.
      expect(find.text('No bookings on this day'), findsOneWidget);
    });

    testWidgets(
        'the day shortcut skips the date picker and pre-fills the tapped day',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject(bookings: [bookingOn(today)]));
      await pumpScreen(tester);

      await tester.tap(find.byKey(ValueKey('calendar-day-${otherDay.day}')));
      await pumpScreen(tester);

      await tester.tap(find.text('Book this day'));
      await pumpScreen(tester);

      // No date picker: the flow starts directly at the start-time picker.
      expect(find.text('Start time'), findsOneWidget);

      // Start 08:00 -> OK, end 12:00 -> OK.
      await tester.tap(find.text('OK'));
      await pumpScreen(tester);
      await tester.tap(find.text('OK'));
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).last, 'From calendar');
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final captured = verify(() => mockRepo.createBooking(
            boatId,
            startsAt: captureAny(named: 'startsAt'),
            endsAt: captureAny(named: 'endsAt'),
            purpose: captureAny(named: 'purpose'),
          )).captured;
      expect(
        captured[0],
        DateTime(otherDay.year, otherDay.month, otherDay.day, 8),
      );
      expect(
        captured[1],
        DateTime(otherDay.year, otherDay.month, otherDay.day, 12),
      );
      expect(captured[2], 'From calendar');
    });

    testWidgets('the app bar toggle switches between calendar and full list',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(bookings: [
          bookingOn(today, purpose: 'Sail today'),
          bookingOn(otherDay, id: 'b-2', purpose: 'Sail other day'),
        ]),
      );
      await pumpScreen(tester);

      // Calendar by default: month grid visible, list filtered to today.
      expect(
        find.text(DateFormat.yMMMM('en').format(today)),
        findsOneWidget,
      );
      expect(find.textContaining('Sail other day'), findsNothing);

      await tester.tap(find.byTooltip('List view'));
      await pumpScreen(tester);

      // Full list: no month grid, every booking visible.
      expect(
        find.text(DateFormat.yMMMM('en').format(today)),
        findsNothing,
      );
      expect(find.textContaining('Sail today'), findsOneWidget);
      expect(find.textContaining('Sail other day'), findsOneWidget);

      await tester.tap(find.byTooltip('Calendar view'));
      await pumpScreen(tester);
      expect(
        find.text(DateFormat.yMMMM('en').format(today)),
        findsOneWidget,
      );
    });
  });
}
