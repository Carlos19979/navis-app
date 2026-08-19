import 'package:flutter/foundation.dart';

/// The slice of time an analytics screen is showing: everything, a single year,
/// or a single month of a year.
///
/// One type for the three cases so the aggregation, the header and the chart all
/// agree on what "the period" is, instead of each recomputing its own filter.
/// Shared because both the logbook statistics and cost intelligence need it, and
/// features may not import each other.
@immutable
final class AnalyticsPeriod {
  const AnalyticsPeriod.allTime()
      : year = null,
        month = null;
  const AnalyticsPeriod.year(int this.year) : month = null;
  const AnalyticsPeriod.month(int this.year, int this.month);

  /// Null for all time.
  final int? year;

  /// 1-12, null when the whole year is selected.
  final int? month;

  bool get isAllTime => year == null;
  bool get isWholeYear => year != null && month == null;

  bool contains(DateTime when) {
    if (year == null) return true;
    if (when.year != year) return false;
    return month == null || when.month == month;
  }

  /// Whether a `YYYY-MM` key falls inside the period. The cost series is keyed
  /// by month string, so comparing text beats parsing 180 dates per rebuild.
  bool containsMonthKey(String key) {
    if (year == null) return true;
    if (month == null) return key.startsWith('${_pad4(year!)}-');
    return key == '${_pad4(year!)}-${_pad2(month!)}';
  }

  AnalyticsPeriod withMonth(int? month) => month == null
      ? AnalyticsPeriod.year(year!)
      : AnalyticsPeriod.month(year!, month);

  /// The comparable period before this one: the previous year for a year, the
  /// previous month for a month. Null for all time, which has nothing to
  /// compare against.
  AnalyticsPeriod? get previous => switch ((year, month)) {
        (null, _) => null,
        (final y?, null) => AnalyticsPeriod.year(y - 1),
        (final y?, 1) => AnalyticsPeriod.month(y - 1, 12),
        (final y?, final m?) => AnalyticsPeriod.month(y, m - 1),
      };

  static String _pad2(int value) => value.toString().padLeft(2, '0');
  static String _pad4(int value) => value.toString().padLeft(4, '0');

  @override
  bool operator ==(Object other) =>
      other is AnalyticsPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'AnalyticsPeriod(year: $year, month: $month)';
}
