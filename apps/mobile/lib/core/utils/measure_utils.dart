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

  /// Engine hours: `120,0 h`.
  static String hours(String locale, double value, String unit) =>
      '${_decimals(locale, value, 1)} $unit';

  /// Litres of fuel: `607 L`.
  static String litres(String locale, double value, String unit) =>
      '${_decimals(locale, value, 0)} $unit';

  /// Wave height: `0,4 m`.
  static String waveHeight(String locale, double value) =>
      '${_decimals(locale, value, 1)} m';

  static String _decimals(String locale, double value, int digits) =>
      NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: digits,
      ).format(value);
}
