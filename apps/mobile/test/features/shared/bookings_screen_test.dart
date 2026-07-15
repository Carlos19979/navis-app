// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  late _MockSharedRepository mockRepo;

  setUp(() {
    mockRepo = _MockSharedRepository();
  });

  Widget buildSubject({
    List<Booking> bookings = const [],
    Future<List<Booking>> Function()? fetch,
    List<BoatMember> members = const [],
  }) {
    return buildTestApp(
      const BookingsScreen(boatId: boatId),
      overrides: [
        sharedRepositoryProvider.overrideWithValue(mockRepo),
        boatBookingsProvider.overrideWith(
          (ref, id) => fetch != null ? fetch() : Future.value(bookings),
        ),
        boatMembersProvider.overrideWith((ref, id) async => members),
      ],
    );
  }

  runAsyncStateMatrix<List<Booking>>(
    screen: 'BookingsScreen',
    build: (override) => buildTestApp(
      const BookingsScreen(boatId: boatId),
      overrides: [
        sharedRepositoryProvider.overrideWithValue(_MockSharedRepository()),
        override,
        boatMembersProvider.overrideWith((ref, id) async => <BoatMember>[]),
      ],
    ),
    override: (fetch) =>
        boatBookingsProvider.overrideWith((ref, id) => fetch()),
    empty: [],
    populated: [makeBooking()],
    emptyFinder: () => find.text('No bookings yet'),
    populatedFinder: () => find.textContaining('Weekend sail'),
  );

  group('BookingsScreen booker names', () {
    testWidgets(
        'shows You for own bookings, member name for members and Crew as fallback',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(
        buildSubject(
          bookings: [
            // Factory default userId is user-1, the session user.
            makeBooking(id: 'b-1', purpose: null),
            makeBooking(
              id: 'b-2',
              userId: 'user-2',
              purpose: null,
              startsAt: DateTime(2026, 5, 2, 10),
              endsAt: DateTime(2026, 5, 2, 18),
            ),
            makeBooking(
              id: 'b-3',
              userId: 'user-3',
              purpose: null,
              startsAt: DateTime(2026, 5, 3, 10),
              endsAt: DateTime(2026, 5, 3, 18),
            ),
          ],
          // Factory defaults: userId user-2, name Maria.
          members: [makeBoatMember()],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('You'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('Crew'), findsOneWidget);
    });
  });

  group('BookingsScreen create flow', () {
    Future<void> tapOk(WidgetTester tester) async {
      await tester.tap(find.text('OK'));
      await pumpScreen(tester);
    }

    testWidgets(
        'creates a booking through date, time pickers and purpose dialog',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      // Empty state CTA and FAB both say "Book a day": use the FAB.
      await tester.tap(find.byTooltip('Book a day'));
      await pumpScreen(tester);

      // Date picker (defaults to today) -> OK.
      await tapOk(tester);
      // Start time picker (08:00) -> OK.
      await tapOk(tester);
      // End time picker (12:00) -> OK.
      await tapOk(tester);

      // Purpose dialog.
      await tester.enterText(find.byType(TextField).last, 'Fishing');
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final now = DateTime.now();
      final captured = verify(() => mockRepo.createBooking(
            boatId,
            startsAt: captureAny(named: 'startsAt'),
            endsAt: captureAny(named: 'endsAt'),
            purpose: captureAny(named: 'purpose'),
          )).captured;
      final start = captured[0] as DateTime;
      final end = captured[1] as DateTime;
      expect(start, DateTime(now.year, now.month, now.day, 8));
      expect(end, DateTime(now.year, now.month, now.day, 12));
      expect(captured[2], 'Fishing');
    });

    testWidgets('end at or before start rolls the end to the next day',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Book a day'));
      await pumpScreen(tester);

      // Date -> OK, start 08:00 -> OK.
      await tapOk(tester);
      await tapOk(tester);

      // End time: switch to text input and set 07:00 AM (before start).
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField).at(0), '7');
      await tester.enterText(find.byType(TextField).at(1), '00');
      await tester.tap(find.text('AM'));
      await pumpScreen(tester);
      await tapOk(tester);

      await tester.enterText(find.byType(TextField).last, 'Overnight');
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final now = DateTime.now();
      final captured = verify(() => mockRepo.createBooking(
            boatId,
            startsAt: captureAny(named: 'startsAt'),
            endsAt: captureAny(named: 'endsAt'),
            purpose: captureAny(named: 'purpose'),
          )).captured;
      final start = captured[0] as DateTime;
      final end = captured[1] as DateTime;
      expect(start, DateTime(now.year, now.month, now.day, 8));
      // 07:00 <= 08:00 start: the booking rolls over to 07:00 the next day.
      expect(
        end,
        DateTime(now.year, now.month, now.day, 7).add(const Duration(days: 1)),
      );
    });

    testWidgets('overlap warning cancel aborts the booking', (tester) async {
      setPhoneSize(tester);
      final now = DateTime.now();
      final clashing = makeBooking(
        startsAt: DateTime(now.year, now.month, now.day, 9),
        endsAt: DateTime(now.year, now.month, now.day, 10),
      );

      await tester.pumpWidget(buildSubject(bookings: [clashing]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Book a day'));
      await pumpScreen(tester);
      await tapOk(tester); // date: today
      await tapOk(tester); // start 08:00
      await tapOk(tester); // end 12:00 (overlaps 09:00-10:00)

      expect(find.text('Overlaps another booking'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          ));
    });

    testWidgets('overlap warning book-anyway proceeds with the booking',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          )).thenAnswer((_) async {});
      final now = DateTime.now();
      final clashing = makeBooking(
        startsAt: DateTime(now.year, now.month, now.day, 9),
        endsAt: DateTime(now.year, now.month, now.day, 10),
      );

      await tester.pumpWidget(buildSubject(bookings: [clashing]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Book a day'));
      await pumpScreen(tester);
      await tapOk(tester);
      await tapOk(tester);
      await tapOk(tester);

      await tester.tap(find.text('Book anyway'));
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).last, 'Race day');
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      verify(() => mockRepo.createBooking(
            boatId,
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: 'Race day',
          )).called(1);
    });
  });

  group('BookingsScreen delete', () {
    testWidgets('delete confirm calls deleteBooking', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.deleteBooking(boatId, 'booking-1'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject(bookings: [makeBooking()]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Delete'));
      await pumpScreen(tester);

      expect(find.text('Delete booking'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await pumpScreen(tester);

      verify(() => mockRepo.deleteBooking(boatId, 'booking-1')).called(1);
    });

    testWidgets('delete cancel keeps the booking', (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject(bookings: [makeBooking()]));
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('Delete'));
      await pumpScreen(tester);
      await tester.tap(find.text('Cancel'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.deleteBooking(any(), any()));
      expect(find.textContaining('Weekend sail'), findsOneWidget);
    });
  });
}
