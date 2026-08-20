import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/core/theme/theme_colors.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';

/// The slice of time the expenses ledger is showing: a single month, or a whole
/// year when [month] is null.
///
/// Replaces the screen-private `_ExpensePeriod` enum plus a loose `_anchor`
/// DateTime: two pieces of state that had to be kept consistent by hand.
@immutable
final class ExpensePeriod {
  const ExpensePeriod.month(this.year, int this.month);

  const ExpensePeriod.wholeYear(this.year) : month = null;

  /// The period the ledger opens on.
  factory ExpensePeriod.current([DateTime? now]) {
    final today = now ?? DateTime.now();
    return ExpensePeriod.month(today.year, today.month);
  }

  final int year;

  /// 1-12, or null for the whole year.
  final int? month;

  bool get isWholeYear => month == null;

  /// The ledger's filter: whether an expense date falls inside the period.
  bool contains(DateTime date) =>
      date.year == year && (month == null || date.month == month);

  /// First day of the period, for formatting.
  DateTime get start => DateTime(year, month ?? 1);

  /// Same year, a different month — used when a year subtotal is tapped.
  ExpensePeriod withMonth(int month) => ExpensePeriod.month(year, month);

  @override
  bool operator ==(Object other) =>
      other is ExpensePeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'ExpensePeriod($year, $month)';
}

/// Localized label for a period: `julio de 2026` in Spanish, `July 2026` in
/// English, and the bare year when the whole year is selected.
///
/// Passing the locale is the whole point of this helper. `DateFormat.yMMMM()`
/// with no locale falls back to `Intl.systemLocale`, which is how the expenses
/// screen printed "July 2026" with the app in Spanish.
String expensePeriodLabel(BuildContext context, ExpensePeriod period) {
  if (period.isWholeYear) return period.year.toString();
  final locale = Localizations.localeOf(context).toLanguageTag();
  return toBeginningOfSentenceCase(
    DateFormat.yMMMM(locale).format(period.start),
    locale,
  );
}

/// Localized full month name (`julio` / `July`), for the year breakdown rows
/// where the year is already implied by the selected period.
String expenseMonthName(BuildContext context, int year, int month) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return toBeginningOfSentenceCase(
    DateFormat.MMMM(locale).format(DateTime(year, month)),
    locale,
  );
}

/// Localized short month name (`ene.` / `Jan`), for the picker grid.
String _monthLabel(BuildContext context, int year, int month) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return toBeginningOfSentenceCase(
    DateFormat.MMM(locale).format(DateTime(year, month)),
    locale,
  );
}

/// The period control for the expenses ledger: one tap opens a picker.
///
/// Supersedes the Month/Year segmented toggle plus `‹ ›` arrows, which needed
/// one tap per step — twelve to reach the same month last year.
class ExpensePeriodSelector extends StatelessWidget {
  const ExpensePeriodSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final ExpensePeriod period;
  final ValueChanged<ExpensePeriod> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showExpensePeriodPicker(context, initial: period);
    if (picked != null && picked != period) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Semantics(
      button: true,
      label: l.expensesSelectPeriod,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(Dimens.radiusPill),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: Dimens.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spaceLg,
            vertical: Dimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: context.glassBg,
            borderRadius: BorderRadius.circular(Dimens.radiusPill),
            border: Border.all(color: context.glassBorderColor, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: Dimens.iconSm,
                color: context.accent,
              ),
              const SizedBox(width: Dimens.spaceSm),
              Text(
                expensePeriodLabel(context, period),
                style: TextStyle(
                  color: context.txtPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Dimens.spaceXs),
              Icon(
                Icons.expand_more_rounded,
                size: Dimens.iconSm,
                color: context.txtSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Month-and-year picker for the expenses ledger. Returns null when dismissed.
Future<ExpensePeriod?> showExpensePeriodPicker(
  BuildContext context, {
  required ExpensePeriod initial,
}) {
  return showDialog<ExpensePeriod>(
    context: context,
    builder: (_) => _ExpensePeriodDialog(initial: initial),
  );
}

class _ExpensePeriodDialog extends StatefulWidget {
  const _ExpensePeriodDialog({required this.initial});

  final ExpensePeriod initial;

  @override
  State<_ExpensePeriodDialog> createState() => _ExpensePeriodDialogState();
}

class _ExpensePeriodDialogState extends State<_ExpensePeriodDialog> {
  late int _year = widget.initial.year;

  bool _isSelected(int month) =>
      !widget.initial.isWholeYear &&
      widget.initial.year == _year &&
      widget.initial.month == month;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: context.dialogSurface,
      title: Text(
        l.expensesSelectPeriod,
        style: TextStyle(color: context.txtPrimary),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: l.expensesPrevPeriod,
                  onPressed: () => setState(() => _year--),
                ),
                Text(
                  '$_year',
                  style: TextStyle(
                    color: context.txtPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: l.expensesNextPeriod,
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: Dimens.spaceSm),
            Wrap(
              spacing: Dimens.spaceSm,
              runSpacing: Dimens.spaceSm,
              alignment: WrapAlignment.center,
              children: [
                for (var month = 1; month <= 12; month++)
                  ChoiceChip(
                    label: Text(_monthLabel(context, _year, month)),
                    selected: _isSelected(month),
                    onSelected: (_) => Navigator.of(context).pop(
                      ExpensePeriod.month(_year, month),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            ExpensePeriod.wholeYear(_year),
          ),
          child: Text(l.expensesPeriodWholeYear),
        ),
      ],
    );
  }
}
