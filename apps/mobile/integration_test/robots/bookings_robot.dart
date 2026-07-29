import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/shared/presentation/screens/bookings_screen.dart';
import 'package:navis_mobile/features/shared/presentation/widgets/booking_form_sheet.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

import '../helpers/pumping.dart';

/// Drives the bookings screen (Pro, shared-boat coordination).
///
/// A booking is a **range** now — departure date+time to arrival date+time —
/// created through **one** entry point: the screen's FAB. The calendar lost its
/// 'Book this day' button and is read-only: tapping a day only moves the panel
/// below it (and prefills the form), so this robot never expects a tap on the
/// grid to book anything.
///
/// Everything is scoped to [BookingsScreen] or to the [BookingFormSheet]: the
/// boat detail hub stays mounted underneath, and the same date string can be on
/// the calendar header, the day panel and both picker buttons at once.
class BookingsRobot {
  BookingsRobot(this.tester);

  final WidgetTester tester;

  /// Marker for the bookings screen: the FAB, the single way in. Present in the
  /// empty state too, so it also works as "the screen loaded".
  static Finder get screenMarker => find.byTooltip('Book');

  Finder _inScreen(Finder matching) => find.descendant(
        of: find.byType(BookingsScreen),
        matching: matching,
      );

  Finder _inSheet(Finder matching) => find.descendant(
        of: find.byType(BookingFormSheet),
        matching: matching,
      );

  /// The range form is on screen. Its hint line is the one string that belongs
  /// to the sheet alone — 'Book' is both the FAB label and the sheet title.
  Finder get _form =>
      find.text('From departure to arrival. Same day for a day out.');

  Finder get _saveButton => _inSheet(find.widgetWithText(NavisButton, 'Save'));

  /// Books [departure] → [arrival] through the FAB form, setting both dates and
  /// the departure time with the real pickers.
  ///
  /// The arrival time is left on the form's default (18:00): one end proves the
  /// time picker works, and keeping the other untouched proves the default is a
  /// real value that reaches the API and comes back on the card.
  Future<void> bookRange({
    required DateTime departure,
    required DateTime arrival,
    required String purpose,
  }) async {
    await _openForm();

    // A fresh form is a day out: both ends prefilled with the same date.
    expect(
      _buttonLabel(const ValueKey('booking-start-date')),
      _buttonLabel(const ValueKey('booking-end-date')),
      reason: 'the form should open on a same-day range',
    );

    await _pickDate(const ValueKey('booking-start-date'), departure);
    await _pickTime(const ValueKey('booking-start-time'), departure);
    await _pickDate(const ValueKey('booking-end-date'), arrival);
    await _enterPurpose(purpose);
    await _save(departure, arrival);

    // No "is it listed?" check here on purpose: the calendar view only shows the
    // selected day's bookings, and a range days ahead can be in a month the grid
    // is not even displaying. The sheet closing means the API took it (a failed
    // create keeps the form open with an error); showing it is the journey's job,
    // through [selectDay] and [expectRangeCard].
    await pumpFor(tester, const Duration(seconds: 1));
  }

  /// Single Save tap, then waits for one of the two things that can happen: the
  /// sheet closes (created) or the API's overlap confirm appears.
  ///
  /// Retapping is not an option here — the second tap would land on the confirm
  /// dialog's barrier and could double-submit — and an unexpected overlap
  /// deserves to say so: it means the range collided with a booking another
  /// journey made, not that the form is broken.
  Future<void> _save(DateTime departure, DateTime arrival) async {
    await pumpUntilFound(tester, _saveButton);
    await tester.ensureVisible(_saveButton.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(_saveButton.first, warnIfMissed: false);
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Book anyway').evaluate().isNotEmpty) {
        throw TestFailure(
          'the API rejected $departure → $arrival as overlapping: pick a window '
          'no other journey uses (J04 books the default slot on today)',
        );
      }
      if (_form.evaluate().isEmpty) return;
    }
    throw TestFailure('the booking form never closed after Save');
  }

  /// Selects [day] on the calendar and asserts nothing gets booked by it: the
  /// grid is a view, not a shortcut. Walks the month chevrons when needed.
  Future<void> selectDay(DateTime day) async {
    await _showMonthOf(day);
    final cell = _inScreen(find.byKey(ValueKey('calendar-day-${day.day}')));
    await pumpUntilFound(tester, cell);
    await tester.tap(cell.first, warnIfMissed: false);
    await pumpFor(tester, const Duration(milliseconds: 500));
    // The panel below the grid follows the selection.
    await pumpUntilFound(
      tester,
      _inScreen(find.text(NavisDateUtils.formatDate(day))),
    );
    expect(
      _form,
      findsNothing,
      reason: 'the calendar is read-only: a day tap must not open the form',
    );
  }

  /// A booking touching [day] paints the cell as taken (the cyan 'mine' dot), so
  /// a multi-day range reads as one block across the grid.
  void expectDayOccupied(DateTime day) {
    expect(
      _inScreen(find.byKey(ValueKey('calendar-day-${day.day}-mine'))),
      findsOneWidget,
      reason: 'day ${day.day} is inside the booked range',
    );
  }

  void expectDayFree(DateTime day) {
    expect(
      _inScreen(find.byKey(ValueKey('calendar-day-${day.day}-mine'))),
      findsNothing,
      reason: 'day ${day.day} is outside the booked range',
    );
  }

  /// The booking's card: departure and arrival spelled out with date **and**
  /// time, plus who booked it and why.
  void expectRangeCard({
    required DateTime departure,
    required DateTime arrival,
    required String purpose,
  }) {
    expect(_inScreen(find.text('Departure')), findsOneWidget);
    expect(_inScreen(find.text('Arrival')), findsOneWidget);
    expect(
      _inScreen(find.text(NavisDateUtils.formatDateTime(departure))),
      findsOneWidget,
    );
    expect(
      _inScreen(find.text(NavisDateUtils.formatDateTime(arrival))),
      findsOneWidget,
    );
    expect(_inScreen(find.text('You · $purpose')), findsOneWidget);
  }

  /// One way to book, and only one: the FAB.
  ///
  /// Call it with a booking already created — the empty state offers the same
  /// action as its CTA, and that one disappears as soon as the list has
  /// content. What must never come back is a per-day button on the calendar or
  /// a second one in the list.
  void expectSingleBookingEntryPoint() {
    expect(
      _inScreen(find.text('Book')),
      findsOneWidget,
      reason: 'the FAB must be the only way to create a booking',
    );
  }

  /// App-bar toggle: calendar ⇄ full list.
  Future<void> openListView() async {
    await tapUntil(
      tester,
      find.byTooltip('List view'),
      find.byTooltip('Calendar view'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  Future<void> openCalendarView() async {
    await tapUntil(
      tester,
      find.byTooltip('Calendar view'),
      find.byTooltip('List view'),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  Future<void> _openForm() async {
    await pumpUntilGone(
      tester,
      find.byType(SnackBar),
      timeout: const Duration(seconds: 8),
    );
    await tapUntil(tester, screenMarker, _form);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  Future<void> _enterPurpose(String purpose) async {
    final field = _inSheet(
      find.descendant(
        of: find.widgetWithText(NavisTextField, 'Purpose (optional)'),
        matching: find.byType(TextField),
      ),
    );
    await pumpUntilFound(tester, field);
    await enterTextChecked(tester, field, purpose);
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  /// Taps the [key] date button and picks [target] in the Material date picker,
  /// walking forward month by month (bookings are made ahead, never behind).
  Future<void> _pickDate(ValueKey<String> key, DateTime target) async {
    await tapUntil(
        tester, _inSheet(find.byKey(key)), find.byType(DatePickerDialog));
    await pumpFor(tester, const Duration(milliseconds: 600));

    final wantedMonth =
        DateFormat.yMMMM('en').format(DateTime(target.year, target.month));
    Finder inDialog(Finder m) =>
        find.descendant(of: find.byType(DatePickerDialog), matching: m);
    for (var i = 0; inDialog(find.text(wantedMonth)).evaluate().isEmpty; i++) {
      if (i == 13) {
        throw TestFailure('date picker never reached $wantedMonth');
      }
      await tester.tap(inDialog(find.byTooltip('Next month')).first);
      await pumpFor(tester, const Duration(milliseconds: 500));
    }

    final day = inDialog(find.text('${target.day}'));
    await pumpUntilFound(tester, day);
    await tester.tap(day.first);
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tapUntilGone(
      tester,
      inDialog(find.text('OK')),
      find.byType(DatePickerDialog),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(
      _buttonLabel(key),
      NavisDateUtils.formatDate(target),
      reason: 'the picked date should show on its form button',
    );
  }

  /// Taps the [key] time button and types [target]'s time into the Material
  /// time picker (its input mode — a dial drag is not reproducible).
  Future<void> _pickTime(ValueKey<String> key, DateTime target) async {
    await tapUntil(
      tester,
      _inSheet(find.byKey(key)),
      find.byType(TimePickerDialog),
    );
    await pumpFor(tester, const Duration(milliseconds: 600));
    Finder inDialog(Finder m) =>
        find.descendant(of: find.byType(TimePickerDialog), matching: m);

    // Dial → keyboard entry.
    final toggle = inDialog(find.byIcon(Icons.keyboard_outlined));
    await pumpUntilFound(tester, toggle);
    await tester.tap(toggle.first);
    await pumpFor(tester, const Duration(milliseconds: 500));

    final fields = inDialog(find.byType(TextField));
    await pumpUntilFound(tester, fields);
    expect(fields, findsNWidgets(2), reason: 'hour and minute fields');
    await tester.enterText(
      fields.at(0),
      target.hour.toString().padLeft(2, '0'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      fields.at(1),
      target.minute.toString().padLeft(2, '0'),
    );
    await tester.pump(const Duration(milliseconds: 200));
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(tester, const Duration(milliseconds: 300));

    await tapUntilGone(
      tester,
      inDialog(find.text('OK')),
      find.byType(TimePickerDialog),
    );
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(
      _buttonLabel(key),
      NavisDateUtils.formatTime(target),
      reason: 'the picked time should show on its form button',
    );
  }

  /// Text shown on one of the form's four date/time buttons.
  String _buttonLabel(ValueKey<String> key) {
    final label = find.descendant(
      of: _inSheet(find.byKey(key)),
      matching: find.byType(Text),
    );
    expect(label, findsOneWidget, reason: 'form button $key');
    return tester.widget<Text>(label.first).data ?? '';
  }

  /// Walks the calendar's next-month chevron until [day]'s month is displayed.
  Future<void> _showMonthOf(DateTime day) async {
    final wanted = DateFormat.yMMMM('en').format(DateTime(day.year, day.month));
    for (var i = 0; _inScreen(find.text(wanted)).evaluate().isEmpty; i++) {
      if (i == 13) {
        throw TestFailure('calendar never reached $wanted');
      }
      await tester.tap(_inScreen(find.byTooltip('Next month')).first);
      await pumpFor(tester, const Duration(milliseconds: 500));
    }
  }
}
