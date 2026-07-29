import 'package:flutter_test/flutter_test.dart';

import '../helpers/bootstrap.dart';
import '../helpers/pumping.dart';
import '../robots/boat_robot.dart';
import '../robots/bookings_robot.dart';
import '../robots/nav_robot.dart';

/// J11 — Bookings as ranges (Pro, set in J02): book the boat from a departure
/// date+time to an arrival date+time two days later, see all three days it
/// crosses marked as taken on the calendar, and read the range off the card in
/// both the day panel and the full list.
///
/// Bookings used to be a single day with 08:00 and +4h baked in, offered by
/// **two** buttons that both booked (the screen's and the calendar's 'Book this
/// day') — which is what made people book the wrong thing. Now there is one
/// entry point, the FAB, and the calendar only shows occupancy. Both halves of
/// that are asserted here: the range round-trips, and the grid never books.
void j11Bookings() {
  testWidgets('j11 bookings: multi-day range, occupancy, single entry point',
      (tester) async {
    await bootstrapApp(tester);
    await ensureSignedIn();
    await pumpFor(tester, const Duration(seconds: 1));
    final boat = BoatRobot(tester);
    final nav = NavRobot(tester);
    final bookings = BookingsRobot(tester);

    await nav.home();
    await boat.openDetail('Aurora');
    await boat.openTile('Bookings', BookingsRobot.screenMarker);

    // A three-day range plus a free day after it, all inside one month grid: the
    // calendar paints only the displayed month, so a range spilling into the next
    // one could not be checked cell by cell.
    //
    // It starts four days out on purpose. J04 books the form's default slot on
    // *today*, and the API refuses overlapping ranges without a confirmation —
    // this journey is about the range itself, not about clashes.
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final fitsThisMonth = now.day + 7 <= daysInMonth;
    final firstDay = fitsThisMonth
        ? DateTime(now.year, now.month, now.day + 4)
        : DateTime(now.year, now.month + 1, 4);
    final departure = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day,
      7,
      30,
    );
    final arrival = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day + 2,
      18,
    );

    // Book it: departure date + time and arrival date through the real pickers.
    await bookings.bookRange(
      departure: departure,
      arrival: arrival,
      purpose: 'Island hop',
    );

    // The calendar is a view, not a shortcut: selecting a day books nothing.
    await bookings.selectDay(departure);
    bookings.expectSingleBookingEntryPoint();

    // Every day the range crosses is taken — including the middle one, which
    // the old per-day filter used to miss — and the day after is free again.
    bookings.expectDayOccupied(departure);
    bookings.expectDayOccupied(
      DateTime(firstDay.year, firstDay.month, firstDay.day + 1),
    );
    bookings.expectDayOccupied(arrival);
    bookings.expectDayFree(
      DateTime(firstDay.year, firstDay.month, firstDay.day + 3),
    );

    // The selected day's panel spells the range out with both times.
    bookings.expectRangeCard(
      departure: departure,
      arrival: arrival,
      purpose: 'Island hop',
    );

    // Same range in the full list, still with one way to book.
    await bookings.openListView();
    bookings.expectRangeCard(
      departure: departure,
      arrival: arrival,
      purpose: 'Island hop',
    );
    bookings.expectSingleBookingEntryPoint();
    await bookings.openCalendarView();

    // Leave the stack as we found it: bookings → hub → dashboard.
    await boat.backToHub(BookingsRobot.screenMarker);
    await boat.closeDetail();
  });
}
