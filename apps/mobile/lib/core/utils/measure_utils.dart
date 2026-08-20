import 'package:intl/intl.dart';

/// Measurements, in the app's language.
///
/// The same gap [Money] closed for currency, for the units this app is full of.
/// `'${boat.lengthMeters} m'` printed **"12.5 m"** with the app in Spanish,
/// where the decimal separator is a comma — and Dart's `toStringAsFixed` always
/// writes a point, so every hand-interpolated measurement in the app has the
/// same bug.
///
/// The locale is passed in, never defaulted, for the reason [Money] gives: a
/// formatter that quietly falls back to the system locale is how the expenses
/// screen ended up printing "July 2026" in a Spanish app.
abstract final class Measure {
  /// Boat length and the like: `12,5 m`.
  static String metres(String locale, double value) =>
      '${_decimals(locale, value, 1)} m';

  /// Distance in nautical miles, with the precision the magnitude deserves:
  /// under ten miles the tenth matters, past that it does not.
  static String nauticalMiles(String locale, double value, String unit) =>
      '${_decimals(locale, value, value < 10 ? 1 : 0)} $unit';

  /// Speed over ground: `7,1 kt`.
  static String knots(String locale, double value, String unit) =>
      '${_decimals(locale, value, 1)} $unit';

  /// Wind, as a whole number of knots: `12 kt`.
  ///
  /// Two decisions in one line. It rounds, unlike [knots]: that one is *speed
  /// over ground*, where the tenth is the difference between two sail trims,
  /// while nobody trims for a tenth of a knot of forecast wind and «9,0 kt» in
  /// a weekly glance is three characters of noise per row. And the unit is the
  /// symbol, not `l.knots` — that string is the *word* («nudos»), which is
  /// right in prose and far too long for a 68 dp column; the symbol is `kt` in
  /// both languages, like the `m` in [metres].
  static String windKnots(String locale, double value) =>
      '${_decimals(locale, value, 0)} kt';

  /// Engine hours: `120,0 h`.
  static String hours(String locale, double value, String unit) =>
      '${_decimals(locale, value, 1)} $unit';

  /// Litres of fuel: `607 L`.
  static String litres(String locale, double value, String unit) =>
      '${_decimals(locale, value, 0)} $unit';

  /// A bare number, for the cases where the *string* already carries the unit
  /// («Olas {wave} m»). Still goes through here: the unit was never the bug —
  /// the decimal point was, and `toStringAsFixed` writes one whatever the
  /// language.
  static String decimal(String locale, double value, {int digits = 1}) =>
      _decimals(locale, value, digits);

  /// A height relative to a datum, sign always shown: `+1,2 m`, `-0,3 m`.
  ///
  /// Tide tables read as a delta, so the plus is information, not decoration —
  /// and it was being glued on by hand next to a `toStringAsFixed`, which is
  /// the same decimal-separator bug this class exists for.
  static String signedMetres(String locale, double value) =>
      '${value >= 0 ? '+' : ''}${_decimals(locale, value, 1)} m';

  /// Wave height: `0,4 m`.
  static String waveHeight(String locale, double value) =>
      '${_decimals(locale, value, 1)} m';

  static String _decimals(String locale, double value, int digits) =>
      NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: digits,
      ).format(value);
}
