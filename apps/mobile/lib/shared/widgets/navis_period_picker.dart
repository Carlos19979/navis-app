import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:navis_mobile/core/theme/dimens.dart';
import 'package:navis_mobile/l10n/app_localizations.dart';
import 'package:navis_mobile/shared/models/analytics_period.dart';
import 'package:navis_mobile/shared/widgets/navis_period_chip.dart';

/// Abbreviated month names in the app's language.
///
/// The locale is passed explicitly: a bare `DateFormat.MMM()` follows
/// `Intl.defaultLocale`, which the app never sets, so a chart labelled its
/// months in English while the rest of the screen was in Spanish.
/// `flutter_localizations` has already registered the symbols for every locale.
List<String> navisShortMonthNames(BuildContext context) =>
    DateFormat.MMM(Localizations.localeOf(context).languageCode)
        .dateSymbols
        .SHORTMONTHS;

/// Year row, plus a month row once a year is chosen. Only periods that have data
/// are offered, so there is nothing to tap that leads to an empty screen.
class NavisPeriodPicker extends StatelessWidget {
  const NavisPeriodPicker({
    super.key,
    required this.period,
    required this.years,
    required this.monthsWithData,
    required this.onChanged,
  });

  final AnalyticsPeriod period;

  /// Years that have data, most recent first.
  final List<int> years;

  /// Months (1-12) of the selected year that have data. Ignored when no year is
  /// selected.
  final Set<int> monthsWithData;

  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final monthNames = navisShortMonthNames(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              NavisPeriodChip(
                label: l.allTime,
                selected: period.isAllTime,
                onTap: () => onChanged(const AnalyticsPeriod.allTime()),
              ),
              for (final year in years) ...[
                const SizedBox(width: Dimens.spaceSm),
                NavisPeriodChip(
                  label: '$year',
                  selected: period.year == year,
                  onTap: () => onChanged(AnalyticsPeriod.year(year)),
                ),
              ],
            ],
          ),
        ),
        if (period.year != null) ...[
          const SizedBox(height: Dimens.spaceSm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                NavisPeriodChip(
                  label: l.wholeYear,
                  selected: period.month == null,
                  onTap: () => onChanged(period.withMonth(null)),
                  compact: true,
                ),
                for (var month = 1; month <= 12; month++)
                  if (monthsWithData.contains(month)) ...[
                    const SizedBox(width: 6),
                    NavisPeriodChip(
                      label: monthNames[month - 1],
                      selected: period.month == month,
                      onTap: () => onChanged(period.withMonth(month)),
                      compact: true,
                    ),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The period spelled out for a card header: `Total histórico`, `2026`,
/// `Julio 2026`.
String navisPeriodLabel(
  BuildContext context,
  AppLocalizations l,
  AnalyticsPeriod period,
) {
  if (period.isAllTime) return l.allTime;
  if (period.month == null) return '${period.year}';
  final month = DateFormat.MMMM(Localizations.localeOf(context).languageCode)
      .format(DateTime(period.year!, period.month!));
  return '${_capitalize(month)} ${period.year}';
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
