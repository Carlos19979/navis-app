// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/shared/presentation/widgets/booking_form_sheet.dart';

import '../../helpers/helpers.dart';

class _MockSharedRepository extends Mock implements SharedRepository {}

/// Minimal host that opens the sheet, so the sheet can pop itself the way it
/// does in the app.
class _Host extends StatelessWidget {
  const _Host({required this.boatId, required this.initialDay});

  final String boatId;
  final DateTime initialDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showBookingFormSheet(
            context,
            boatId: boatId,
            initialDay: initialDay,
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  const boatId = 'boat-1';

  // A fixed future day keeps the pickers deterministic: both open on May 2030
  // and every day from the 10th on is selectable.
  final day = DateTime(2030, 5, 10);

  late _MockSharedRepository mockRepo;

  setUp(() {
    mockRepo = _MockSharedRepository();
  });

  Widget buildSubject({List<Booking> bookings = const []}) {
    return buildTestApp(
      _Host(boatId: boatId, initialDay: day),
      overrides: [
        sharedRepositoryProvider.overrideWithValue(mockRepo),
        boatBookingsProvider.overrideWith((ref, id) async => bookings),
      ],
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await pumpScreen(tester);
  }

  void stubCreate({bool force = false}) {
    when(() => mockRepo.createBooking(
          any(),
          startsAt: any(named: 'startsAt'),
          endsAt: any(named: 'endsAt'),
          purpose: any(named: 'purpose'),
          force: force,
        )).thenAnswer((_) async {});
  }

  List<dynamic> capturedCreate({bool force = false}) {
    return verify(() => mockRepo.createBooking(
          boatId,
          startsAt: captureAny(named: 'startsAt'),
          endsAt: captureAny(named: 'endsAt'),
          purpose: captureAny(named: 'purpose'),
          force: force,
        )).captured;
  }

  group('BookingFormSheet range form', () {
    testWidgets('prefills a same-day slot: both ends on the tapped day',
        (tester) async {
      setPhoneSize(tester);
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openSheet(tester);

      expect(find.text('Departure'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);
      // Single-day shortcut: same date on both ends, only the times differ.
      expect(find.text('10 May 2030'), findsNWidgets(2));
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
    });

    testWidgets('saves the default same-day range with the purpose',
        (tester) async {
      setPhoneSize(tester);
      stubCreate();
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'Fishing');
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final captured = capturedCreate();
      expect(captured[0], DateTime(2030, 5, 10, 9));
      expect(captured[1], DateTime(2030, 5, 10, 18));
      expect(captured[2], 'Fishing');
      // Created: the sheet closes.
      expect(find.text('Departure'), findsNothing);
    });

    testWidgets('the arrival date picker books a multi-day range',
        (tester) async {
      setPhoneSize(tester);
      stubCreate();
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('booking-end-date')));
      await pumpScreen(tester);
      await tester.tap(find.text('12'));
      await pumpScreen(tester);
      await tester.tap(find.text('OK'));
      await pumpScreen(tester);

      expect(find.text('10 May 2030'), findsOneWidget);
      expect(find.text('12 May 2030'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final captured = capturedCreate();
      expect(captured[0], DateTime(2030, 5, 10, 9));
      expect(captured[1], DateTime(2030, 5, 12, 18));
    });

    testWidgets('moving the departure drags the arrival along', (tester) async {
      setPhoneSize(tester);
      stubCreate();
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('booking-start-date')));
      await pumpScreen(tester);
      await tester.tap(find.text('12'));
      await pumpScreen(tester);
      await tester.tap(find.text('OK'));
      await pumpScreen(tester);

      // The 9h span is preserved, so the range never becomes invalid.
      expect(find.text('12 May 2030'), findsNWidgets(2));

      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      final captured = capturedCreate();
      expect(captured[0], DateTime(2030, 5, 12, 9));
      expect(captured[1], DateTime(2030, 5, 12, 18));
    });

    testWidgets('an arrival before the departure is rejected, not sent',
        (tester) async {
      setPhoneSize(tester);
      stubCreate();
      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openSheet(tester);

      // Arrival time 07:00 on the same day as a 09:00 departure.
      await tester.tap(find.byKey(const ValueKey('booking-end-time')));
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await pumpScreen(tester);
      // Scoped to the dialog: the sheet's purpose field is still in the tree.
      final timeFields = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(timeFields.at(0), '7');
      await tester.enterText(timeFields.at(1), '00');
      await tester.tap(find.text('AM'));
      await pumpScreen(tester);
      await tester.tap(find.text('OK'));
      await pumpScreen(tester);

      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      expect(find.text('Arrival must be after departure'), findsOneWidget);
      verifyNever(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          ));
    });
  });

  group('BookingFormSheet overlap flow', () {
    // The clashing booking the client already has loaded, so the warning can
    // name the taken range.
    final clashing = makeBooking(
      id: 'other',
      startsAt: DateTime(2030, 5, 10, 10),
      endsAt: DateTime(2030, 5, 10, 14),
    );

    void stubOverlap() {
      when(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          )).thenThrow(const BookingOverlapException());
    }

    testWidgets('409 shows the taken range and retries with force',
        (tester) async {
      setPhoneSize(tester);
      stubOverlap();
      stubCreate(force: true);
      await tester.pumpWidget(buildSubject(bookings: [clashing]));
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'Race day');
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      expect(find.text('Overlaps another booking'), findsOneWidget);
      // The warning is actionable: it names the range already booked.
      expect(
        find.textContaining('10 May 2030 10:00-14:00'),
        findsOneWidget,
      );

      await tester.tap(find.text('Book anyway'));
      await pumpScreen(tester);

      final captured = capturedCreate(force: true);
      expect(captured[0], DateTime(2030, 5, 10, 9));
      expect(captured[1], DateTime(2030, 5, 10, 18));
      expect(captured[2], 'Race day');
    });

    testWidgets('cancelling the 409 keeps the form and forces nothing',
        (tester) async {
      setPhoneSize(tester);
      stubOverlap();
      await tester.pumpWidget(buildSubject(bookings: [clashing]));
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'Race day');
      await tester.tap(find.text('Save'));
      await pumpScreen(tester);
      await tester.tap(find.text('Cancel'));
      await pumpScreen(tester);

      verifyNever(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
            force: true,
          ));
      // The sheet stays open with the entered data.
      expect(find.text('Departure'), findsOneWidget);
      expect(find.text('Race day'), findsOneWidget);
    });

    testWidgets('a failed create surfaces an error and keeps the sheet',
        (tester) async {
      setPhoneSize(tester);
      when(() => mockRepo.createBooking(
            any(),
            startsAt: any(named: 'startsAt'),
            endsAt: any(named: 'endsAt'),
            purpose: any(named: 'purpose'),
          )).thenThrow(Exception('boom'));

      await tester.pumpWidget(buildSubject());
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.text('Save'));
      await pumpScreen(tester);

      expectSnackbar(tester, 'Something went wrong');
      expect(find.text('Departure'), findsOneWidget);
    });
  });
}
