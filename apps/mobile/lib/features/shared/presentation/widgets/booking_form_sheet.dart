import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/theme/app_colors.dart';
import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/features/shared/data/shared_repository.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/widgets/navis_button.dart';
import 'package:navis_mobile/shared/widgets/navis_dialog.dart';
import 'package:navis_mobile/shared/widgets/navis_snackbar.dart';
import 'package:navis_mobile/shared/widgets/navis_text_field.dart';

/// Default slot for a fresh booking: a day out, 09:00 → 18:00 (same date, the
/// single-day shortcut — only the times need touching).
const int _defaultStartHour = 9;
const int _defaultEndHour = 18;

/// The one and only way to create a booking. Collects a departure and an
/// arrival (each date + time) plus an optional purpose, and owns the create
/// call so the API's overlap warning can be confirmed without losing the form.
///
/// Returns true when a booking was created, null when dismissed.
Future<bool?> showBookingFormSheet(
  BuildContext context, {
  required String boatId,
  DateTime? initialDay,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: context.dialogSurface,
    builder: (_) => BookingFormSheet(boatId: boatId, initialDay: initialDay),
  );
}

class BookingFormSheet extends ConsumerStatefulWidget {
  const BookingFormSheet({super.key, required this.boatId, this.initialDay});

  final String boatId;

  /// Day to prefill both ends with (the calendar's selected day). Defaults to
  /// today.
  final DateTime? initialDay;

  @override
  ConsumerState<BookingFormSheet> createState() => _BookingFormSheetState();
}

class _BookingFormSheetState extends ConsumerState<BookingFormSheet> {
  final _purpose = TextEditingController();

  late DateTime _start;
  late DateTime _end;

  bool _busy = false;

  /// Set once the user tries to save an arrival that is not after departure.
  bool _showRangeError = false;

  /// Bookings this client already knows about, kept fresh by [build]'s watch.
  List<Booking> _known = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final day = widget.initialDay ?? now;
    _start = DateTime(day.year, day.month, day.day, _defaultStartHour);
    _end = DateTime(day.year, day.month, day.day, _defaultEndHour);
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  bool get _rangeValid => _end.isAfter(_start);

  /// Earliest pickable date: yesterday, or the prefilled day when the calendar
  /// was sitting on an older month.
  DateTime get _firstDate {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    return _start.isBefore(yesterday) ? _start : yesterday;
  }

  /// Two years out from whichever is later, today or the prefilled departure —
  /// so a day picked far ahead is still inside the pickable window.
  DateTime get _lastDate {
    final now = DateTime.now();
    final base = _start.isAfter(now) ? _start : now;
    return DateTime(base.year + 2, base.month, base.day);
  }

  /// Moving the departure drags the arrival along, preserving the duration, so
  /// the range never silently becomes invalid.
  void _setStart(DateTime value) {
    final span = _end.difference(_start);
    setState(() {
      _start = value;
      if (!_end.isAfter(_start)) {
        _end = _start.add(
          span > Duration.zero ? span : const Duration(hours: 4),
        );
      }
      if (_rangeValid) _showRangeError = false;
    });
  }

  void _setEnd(DateTime value) {
    setState(() {
      _end = value;
      if (_rangeValid) _showRangeError = false;
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final l = AppLocalizations.of(context)!;
    final current = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      // The arrival can never precede the departure day.
      firstDate:
          start ? _firstDate : DateTime(_start.year, _start.month, _start.day),
      lastDate: _lastDate,
      helpText: start ? l.bookingDepartureDate : l.bookingArrivalDate,
    );
    if (picked == null) return;
    final merged = DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
    );
    if (start) {
      _setStart(merged);
    } else {
      _setEnd(merged);
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final l = AppLocalizations.of(context)!;
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: start ? l.bookingDepartureTime : l.bookingArrivalTime,
    );
    if (picked == null) return;
    final merged = DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    );
    if (start) {
      _setStart(merged);
    } else {
      _setEnd(merged);
    }
  }

  /// Range of the already-loaded booking this one clashes with, if any — shown
  /// inside the overlap confirmation so the warning is actionable. The API
  /// stays the authority; this only puts a name to its 409.
  String? _clashingRangeLabel() {
    for (final b in _known) {
      if (b.status == 'cancelled') continue;
      if (b.startsAt.isBefore(_end) && b.endsAt.isAfter(_start)) {
        return bookingRangeLabel(b.startsAt, b.endsAt);
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_rangeValid) {
      setState(() => _showRangeError = true);
      return;
    }
    final purpose = _purpose.text.trim();
    final repo = ref.read(sharedRepositoryProvider);
    setState(() => _busy = true);
    try {
      try {
        await repo.createBooking(
          widget.boatId,
          startsAt: _start,
          endsAt: _end,
          purpose: purpose,
        );
      } on BookingOverlapException {
        if (!mounted) return;
        setState(() => _busy = false);
        final clash = _clashingRangeLabel();
        final proceed = await NavisConfirmDialog.show(
          context,
          title: l.bookingOverlapTitle,
          message: clash == null
              ? l.bookingOverlapMessage
              : '${l.bookingOverlapMessage}\n\n'
                  '${l.bookingOverlapDetail(clash)}',
          confirmLabel: l.bookingBookAnyway,
        );
        if (!proceed || !mounted) return;
        setState(() => _busy = true);
        await repo.createBooking(
          widget.boatId,
          startsAt: _start,
          endsAt: _end,
          purpose: purpose,
          force: true,
        );
      }
      ref.invalidate(boatBookingsProvider(widget.boatId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      NavisSnackbar.error(context, l.somethingWentWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Watched, not read on demand: the list must already be loaded when the
    // overlap warning wants to name the range that is taken.
    _known = ref.watch(boatBookingsProvider(widget.boatId)).valueOrNull ??
        const <Booking>[];

    return Padding(
      padding: EdgeInsets.only(
        left: Dimens.spaceLg,
        right: Dimens.spaceLg,
        top: Dimens.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Dimens.spaceLg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.bookingAdd,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.txtPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.bookingRangeHint,
              style: TextStyle(fontSize: 13, color: context.txtSecondary),
            ),
            const SizedBox(height: Dimens.spaceMd),
            _EndRow(
              label: l.bookingDeparture,
              icon: Icons.sailing_outlined,
              value: _start,
              dateKey: const ValueKey('booking-start-date'),
              timeKey: const ValueKey('booking-start-time'),
              dateTooltip: l.bookingDepartureDate,
              timeTooltip: l.bookingDepartureTime,
              onPickDate: () => _pickDate(start: true),
              onPickTime: () => _pickTime(start: true),
            ),
            const SizedBox(height: Dimens.spaceSm),
            _EndRow(
              label: l.bookingArrival,
              icon: Icons.anchor_outlined,
              value: _end,
              dateKey: const ValueKey('booking-end-date'),
              timeKey: const ValueKey('booking-end-time'),
              dateTooltip: l.bookingArrivalDate,
              timeTooltip: l.bookingArrivalTime,
              onPickDate: () => _pickDate(start: false),
              onPickTime: () => _pickTime(start: false),
            ),
            if (_showRangeError)
              Padding(
                padding: const EdgeInsets.only(top: Dimens.spaceSm),
                child: Text(
                  l.bookingEndBeforeStart,
                  style: const TextStyle(fontSize: 13, color: AppColors.red),
                ),
              ),
            const SizedBox(height: Dimens.spaceMd),
            NavisTextField(
              controller: _purpose,
              label: l.bookingPurposeHint,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: Dimens.spaceMd),
            NavisButton(
              label: l.save,
              isLoading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// One end of the range: label plus a date button and a time button.
class _EndRow extends StatelessWidget {
  const _EndRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.dateKey,
    required this.timeKey,
    required this.dateTooltip,
    required this.timeTooltip,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String label;
  final IconData icon;
  final DateTime value;
  final Key dateKey;
  final Key timeKey;
  final String dateTooltip;
  final String timeTooltip;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: Dimens.iconSm, color: context.txtSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.txtSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PickerButton(
                key: dateKey,
                tooltip: dateTooltip,
                text: NavisDateUtils.formatDate(value),
                icon: Icons.calendar_today_outlined,
                onPressed: onPickDate,
              ),
            ),
            const SizedBox(width: Dimens.spaceSm),
            Expanded(
              flex: 2,
              child: _PickerButton(
                key: timeKey,
                tooltip: timeTooltip,
                text: NavisDateUtils.formatTime(value),
                icon: Icons.schedule_outlined,
                onPressed: onPickTime,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.tooltip,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: Dimens.iconSm, color: context.txtSecondary),
        label: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.txtPrimary),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Dimens.minTouchTarget),
          side: BorderSide(color: context.glassBorderColor),
          backgroundColor: context.glassBg,
        ),
      ),
    );
  }
}

/// Compact one-line label for a booking range: `dd MMM yyyy HH:mm` for a
/// single-day slot, both dates when it spans days.
String bookingRangeLabel(DateTime start, DateTime end) {
  final s = start.toLocal();
  final e = end.toLocal();
  if (DateUtils.isSameDay(s, e)) {
    return '${NavisDateUtils.formatDate(s)} '
        '${NavisDateUtils.formatTime(s)}-${NavisDateUtils.formatTime(e)}';
  }
  return '${NavisDateUtils.formatDateTime(s)} - '
      '${NavisDateUtils.formatDateTime(e)}';
}
