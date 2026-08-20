import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/network/supabase_client.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/boat/data/boat_share_repository.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/features/shared/presentation/widgets/booking_form_sheet.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_card.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_empty_state.dart';
import 'package:navis_mobile/shared/widgets/navis_error_widget.dart';
import 'package:navis_mobile/shared/widgets/navis_gradient_fab.dart';
import 'package:navis_mobile/shared/widgets/navis_scaffold.dart';
import 'package:navis_mobile/shared/widgets/navis_shimmer.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';

/// Booking presence markers for one calendar day cell.
typedef _DayInfo = ({bool mine, bool others, bool overlap});

/// True when the booking's range intersects [start, end).
bool _intersects(Booking b, DateTime start, DateTime end) =>
    b.startsAt.isBefore(end) && b.endsAt.isAfter(start);

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key, required this.boatId});

  final String boatId;

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  /// Calendar is the default view; the app-bar action flips to the full list.
  bool _showCalendar = true;

  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  /// Active (non-cancelled) bookings whose range touches [day].
  List<Booking> _bookingsOn(List<Booking> bookings, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return [
      for (final b in bookings)
        if (b.status != 'cancelled' && _intersects(b, start, end)) b,
    ];
  }

  /// Whether any two of the day's bookings intersect each other — the same
  /// range predicate the list badge uses.
  bool _dayHasClash(List<Booking> dayBookings) {
    for (var i = 0; i < dayBookings.length; i++) {
      for (var j = i + 1; j < dayBookings.length; j++) {
        if (_intersects(
          dayBookings[i],
          dayBookings[j].startsAt,
          dayBookings[j].endsAt,
        )) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final async = ref.watch(boatBookingsProvider(widget.boatId));

    return NavisScaffold(
      title: l.bookingsTitle,
      showBack: true,
      actions: [
        IconButton(
          icon: Icon(
            _showCalendar
                ? Icons.view_list_outlined
                : Icons.calendar_month_outlined,
          ),
          tooltip: _showCalendar ? l.bookingsViewList : l.bookingsViewCalendar,
          onPressed: () => setState(() => _showCalendar = !_showCalendar),
        ),
      ],
      floatingActionButton: NavisGradientFab(
        onPressed: _addBooking,
        icon: Icons.add,
        tooltip: l.bookingAdd,
        label: l.bookingAdd,
      ),
      body: async.when(
        loading: () => const NavisShimmer(itemHeight: 80),
        error: (e, _) => NavisErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(boatBookingsProvider(widget.boatId)),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return NavisEmptyState(
              icon: Icons.event_available_outlined,
              message: l.bookingsEmpty,
              description: l.bookingsEmptyDescription,
              actionLabel: l.bookingAdd,
              onAction: _addBooking,
            );
          }
          // Resolve who booked: current user -> "You", else member name.
          final members =
              ref.watch(boatMembersProvider(widget.boatId)).valueOrNull ??
                  const <BoatMember>[];
          final myId = supabaseClient.auth.currentUser?.id;
          String bookerName(String userId) {
            if (userId == myId) return l.bookingYou;
            for (final m in members) {
              if (m.userId == userId && m.name.isNotEmpty) return m.name;
            }
            return l.bookingCrew;
          }

          // Mark bookings whose range intersects another active one, so
          // conflicts stay visible after creation (forced or raced).
          bool clashes(Booking a) =>
              a.status != 'cancelled' &&
              bookings.any((b) =>
                  !identical(a, b) &&
                  b.status != 'cancelled' &&
                  _intersects(a, b.startsAt, b.endsAt));

          Widget card(Booking b) => _BookingCard(
                boatId: widget.boatId,
                booking: b,
                bookerName: bookerName(b.userId),
                overlaps: clashes(b),
              );

          if (!_showCalendar) {
            return ListView.separated(
              padding: const EdgeInsets.all(Dimens.spaceLg),
              itemCount: bookings.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: Dimens.spaceSm),
              itemBuilder: (context, i) => card(bookings[i]),
            );
          }

          final dayBookings = _bookingsOn(bookings, _selectedDay);
          return ListView(
            padding: const EdgeInsets.all(Dimens.spaceLg),
            children: [
              _MonthCalendar(
                month: _month,
                selectedDay: _selectedDay,
                onPrevMonth: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNextMonth: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                onSelectDay: (day) => setState(() => _selectedDay = day),
                infoFor: (day) {
                  final onDay = _bookingsOn(bookings, day);
                  return (
                    mine: onDay.any((b) => b.userId == myId),
                    others: onDay.any((b) => b.userId != myId),
                    overlap: _dayHasClash(onDay),
                  );
                },
              ),
              const SizedBox(height: Dimens.spaceLg),
              Text(
                NavisDateUtils.formatDate(_selectedDay),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.txtPrimary,
                ),
              ),
              const SizedBox(height: Dimens.spaceSm),
              if (dayBookings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Dimens.spaceSm,
                  ),
                  child: Text(
                    l.bookingsNoneOnDay,
                    style: TextStyle(color: context.txtSecondary),
                  ),
                )
              else
                for (final b in dayBookings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Dimens.spaceSm),
                    child: card(b),
                  ),
              const SizedBox(height: Dimens.navClearance),
            ],
          );
        },
      ),
    );
  }

  /// The single booking entry point: the range form sheet. It owns the whole
  /// create flow (validation, the API overlap confirm/force retry and the
  /// provider invalidation). The calendar only prefills the day it is sitting
  /// on — a one-day booking is then just two time taps.
  Future<void> _addBooking() => showBookingFormSheet(
        context,
        boatId: widget.boatId,
        initialDay: _showCalendar ? _selectedDay : null,
      );
}

/// Hand-rolled month grid: header with prev/next chevrons, localized weekday
/// row and 7-column day cells with booking-presence dots.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selectedDay,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
    required this.infoFor,
  });

  /// First day of the displayed month.
  final DateTime month;
  final DateTime selectedDay;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;
  final _DayInfo Function(DateTime day) infoFor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    // Localized start of week: 0 = Sunday … 6 = Saturday.
    final firstDow = material.firstDayOfWeekIndex;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading =
        (DateTime(month.year, month.month).weekday % 7 - firstDow + 7) % 7;
    final now = DateTime.now();

    return NavisCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: context.txtSecondary),
                tooltip: l.bookingPrevMonth,
                onPressed: onPrevMonth,
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.txtPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: context.txtSecondary),
                tooltip: l.bookingNextMonth,
                onPressed: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: Dimens.spaceXs),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    material.narrowWeekdays[(firstDow + i) % 7],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.txtSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Dimens.spaceXs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _DayCell(
                  day: DateTime(month.year, month.month, d),
                  info: infoFor(DateTime(month.year, month.month, d)),
                  selected: DateUtils.isSameDay(
                    selectedDay,
                    DateTime(month.year, month.month, d),
                  ),
                  today: DateUtils.isSameDay(
                    now,
                    DateTime(month.year, month.month, d),
                  ),
                  onTap: onSelectDay,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.info,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final _DayInfo info;
  final bool selected;
  final bool today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    // Any booking touching this day paints it as taken, so a multi-day range
    // reads as one continuous block across the grid.
    final occupied = info.mine || info.others;
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat.yMMMMd(locale).format(day),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(day),
        child: Container(
          key: ValueKey('calendar-day-${day.day}'),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected
                ? context.accent.withValues(alpha: 0.18)
                : occupied
                    ? context.accent.withValues(alpha: 0.07)
                    : null,
            borderRadius: BorderRadius.circular(Dimens.radiusSm),
            // Amber ring: two bookings overlap on this day.
            border: info.overlap
                ? Border.all(color: context.caution, width: 1.5)
                : selected
                    ? Border.all(color: context.accent)
                    : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: today ? FontWeight.w800 : FontWeight.w500,
                  color: today ? context.accent : context.txtPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (info.mine)
                    _Dot(
                      key: ValueKey('calendar-day-${day.day}-mine'),
                      color: context.accent,
                    ),
                  if (info.others)
                    _Dot(
                      key: ValueKey('calendar-day-${day.day}-others'),
                      color: context.txtSecondary,
                    ),
                  if (info.overlap)
                    _Dot(
                      key: ValueKey('calendar-day-${day.day}-overlap'),
                      color: context.caution,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({
    required this.boatId,
    required this.booking,
    required this.bookerName,
    this.overlaps = false,
  });

  final String boatId;
  final Booking booking;
  final String bookerName;

  /// Whether this booking's range intersects another active booking.
  final bool overlaps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final start = booking.startsAt.toLocal();
    final end = booking.endsAt.toLocal();
    // A single-day slot fits one line; a range spells out both ends so nobody
    // has to guess which day the boat comes back.
    final singleDay = DateUtils.isSameDay(start, end);
    return NavisCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event, color: context.accent, size: 22),
          ),
          const SizedBox(width: Dimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (singleDay)
                  Text(
                    '${NavisDateUtils.formatDate(start)}  '
                    '${NavisDateUtils.formatTime(start)}–'
                    '${NavisDateUtils.formatTime(end)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.txtPrimary,
                    ),
                  )
                else ...[
                  _RangeEnd(label: l.bookingDeparture, value: start),
                  _RangeEnd(label: l.bookingArrival, value: end),
                ],
                Text(
                  booking.purpose != null && booking.purpose!.isNotEmpty
                      ? '$bookerName · ${booking.purpose!}'
                      : bookerName,
                  style: TextStyle(fontSize: 13, color: context.txtSecondary),
                ),
                if (overlaps)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: context.caution),
                        const SizedBox(width: 4),
                        Text(
                          l.bookingOverlapsBadge,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.caution,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: context.txtSecondary),
            tooltip: l.delete,
            onPressed: () async {
              final ok = await NavisConfirmDialog.show(
                context,
                title: l.bookingDelete,
                message: l.bookingDeleteConfirm,
                confirmLabel: l.delete,
                destructive: true,
              );
              if (!ok) return;
              try {
                await ref
                    .read(sharedRepositoryProvider)
                    .deleteBooking(boatId, booking.id);
                ref.invalidate(boatBookingsProvider(boatId));
              } catch (_) {
                if (context.mounted) {
                  NavisSnackbar.error(context, l.somethingWentWrong);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

/// One labelled end of a multi-day booking: "Departure  02 May 2026 09:00".
class _RangeEnd extends StatelessWidget {
  const _RangeEnd({required this.label, required this.value});

  final String label;
  final DateTime value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.txtSecondary),
          ),
        ),
        Expanded(
          child: Text(
            NavisDateUtils.formatDateTime(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.txtPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
