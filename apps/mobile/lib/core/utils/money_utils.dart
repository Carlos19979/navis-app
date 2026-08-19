import 'package:intl/intl.dart';

/// Euro formatting, in the app's language.
///
/// Every screen used to interpolate `'${v.toStringAsFixed(0)} €'` by hand, which
/// printed `1250 €` where Spanish wants `1.250 €` — and `NumberFormat` was not
/// used anywhere in the app despite `intl` already being a dependency.
///
/// The locale is passed in, never defaulted: `Intl.defaultLocale` is only set
/// once the app calls `NavisDateUtils.useLocale`, and a formatter that silently
/// falls back to the system locale is how the expenses screen ended up printing
/// "July 2026" with the app in Spanish.
abstract final class Money {
  /// The currency symbol. Navis is euro-only — there is no currency column
  /// anywhere in the schema.
  static const symbol = '€';

  /// Rounded to whole euros: `1.250 €`. What totals and per-category rows use.
  static String format(String locale, double value) =>
      '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 0).format(value)} $symbol';

  /// Two decimals: `1,78 €`. For unit prices, where the cents are the point.
  static String formatPrecise(String locale, double value) =>
      '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2).format(value)} $symbol';

  /// A rate: `1,78 €/L`, `9 €/MN`. [unit] is already localized.
  static String perUnit(
    String locale,
    double value,
    String unit, {
    bool precise = false,
  }) =>
      '${precise ? formatPrecise(locale, value) : format(locale, value)}/$unit';

  /// A signed percentage for a period-over-period delta: `+12 %`, `−8 %`.
  ///
  /// Uses a real minus sign, not a hyphen — at 10pt a hyphen reads as a dash in
  /// the middle of a number.
  static String signedPercent(String locale, double percent) {
    final rounded = percent.round();
    final sign = rounded > 0 ? '+' : (rounded < 0 ? '−' : '');
    return '$sign${NumberFormat.decimalPattern(locale).format(rounded.abs())} %';
  }
}
