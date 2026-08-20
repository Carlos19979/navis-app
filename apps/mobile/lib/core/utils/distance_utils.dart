import 'dart:math';

/// Distance and speed **maths**. The formatting moved to [Measure] — these two
/// printed `toStringAsFixed`, which writes a decimal point in every language,
/// and hard-coded `NM`/`kt` where Spanish uses `MN`.
class DistanceUtils {
  DistanceUtils._();

  static const double _nmToKmFactor = 1.852;

  static double nmToKm(double nm) => nm * _nmToKmFactor;

  static double kmToNm(double km) => km / _nmToKmFactor;

  static double knotsToKmh(double knots) => knots * _nmToKmFactor;

  static double kmhToKnots(double kmh) => kmh / _nmToKmFactor;

  /// Calculate distance between two coordinates using the Haversine formula.
  /// Returns distance in nautical miles.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusNm = 3440.065;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusNm * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
