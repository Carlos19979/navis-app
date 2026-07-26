// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/utils/navis_date_utils.dart';
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

  // The screen opens on the calendar view with today selected, so bookings
  // asserted through the day list must fall on today.
  Booking todayBooking({
    String id = 'booking-1',
    String userId = 'user-1',
    String? purpose = 'Weekend sail',
    int startHour = 10,
    int endHour = 18,
  }) {
    final now = DateTime.now();
    return makeBooking(
      id: id,
      userId: userId,
      purpose: purpose,
      startsAt: DateTime(now.year, now.month, now.day, startHour),
      endsAt: DateTime(now.year, now.month, now.day, endHour),
    );
  }

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
    populated: [todayBooking()],
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
            // Factory default userId is user-1, the session user. All three
            // fall on today (non-overlapping slots) so the calendar's day
            // list shows them.
            todayBooking(id: 'b-1', purpose: null, startHour: 8, endHour: 10),
            todayBooking(
              id: 'b-2',
              userId: 'user-2',
              purpose: null,
              endHour: 12,
            ),
            todayBooking(
              id: 'b-3',
              userId: 'user-3',
              purpose: null,
              startHour: 12,
              endHour: 14,
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
    testWidgets(
        'the FAB is the only entry point and opens the range form on the '
        'selected day', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);

      // Empty state CTA and FAB both say "Book": use the FAB.
      await tester.tap(find.byTooltip('Book'));
      await pumpScreen(tester);

      // The range form: departure and arrival, both prefilled with today.
      expect(find.text('Departure'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);

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
      // Default same-day slot on the calendar's selected day (today).
      expect(captured[0], DateTime(now.year, now.month, now.day, 9));
      expect(captured[1], DateTime(now.year, now.month, now.day, 18));
      expect(captured[2], 'Fishing');
    });

    testWidgets('a multi-day booking spells out departure and arrival',
        (tester) async {
      setPhoneSize(tester);
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 9);
      final end = start.add(const Duration(days: 2, hours: 9));

      await tester.pumpWidget(
        buildSubject(
          bookings: [makeBooking(startsAt: start, endsAt: end)],
        ),
      );
      await pumpScreen(tester);

      expect(find.text('Departure'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);
      expect(find.text(NavisDateUtils.formatDateTime(start)), findsOneWidget);
      expect(find.text(NavisDateUtils.formatDateTime(end)), findsOneWidget);
    });

    testWidgets('overlapping bookings carry the amber badge in the list',
        (tester) async {
      setPhoneSize(tester);
      final now = DateTime.now();
      final a = makeBooking(
        id: 'b1',
        startsAt: DateTime(now.year, now.month, now.day, 9),
        endsAt: DateTime(now.year, now.month, now.day, 12),
      );
      final b = makeBooking(
        id: 'b2',
        startsAt: DateTime(now.year, now.month, now.day, 11),
        endsAt: DateTime(now.year, now.month, now.day, 14),
      );
      final c = makeBooking(
        id: 'b3',
        startsAt: DateTime(now.year, now.month, now.day, 15),
        endsAt: DateTime(now.year, now.month, now.day, 18),
      );

      await tester.pumpWidget(buildSubject(bookings: [a, b, c]));
      await pumpScreen(tester);

      // a & b clash with each other; c is clean.
      expect(find.text('Overlaps another booking'), findsNWidgets(2));
    });
  });

  group('BookingsScreen delete', () {
    testWidgets('delete confirm calls deleteBooking', (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.deleteBooking(boatId, 'booking-1'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject(bookings: [todayBooking()]));
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
      await tester.pumpWidget(buildSubject(bookings: [todayBooking()]));
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
