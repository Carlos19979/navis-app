import 'dart:math';

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

  static String formatDistance(double nm) {
    if (nm < 0.1) {
      return '${(nm * 1852).toStringAsFixed(0)} m';
    }
    if (nm < 10) {
      return '${nm.toStringAsFixed(1)} NM';
    }
    return '${nm.toStringAsFixed(0)} NM';
  }

  static String formatSpeed(double knots) {
    return '${knots.toStringAsFixed(1)} kt';
  }
}
