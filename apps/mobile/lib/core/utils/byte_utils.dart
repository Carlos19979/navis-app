/// Human sizes for on-device storage (offline charts, caches).
abstract final class ByteUtils {
  static const int _kb = 1024;
  static const int _mb = 1024 * 1024;
  static const int _gb = 1024 * 1024 * 1024;

  /// Formats [bytes] as `MB`/`GB`, dropping the decimal once the number is
  /// large enough that it stops meaning anything.
  static String format(int bytes) {
    if (bytes >= _gb) {
      return '${(bytes / _gb).toStringAsFixed(1)} GB';
    }
    if (bytes >= 10 * _mb) {
      return '${(bytes / _mb).round()} MB';
    }
    if (bytes >= _mb) {
      return '${(bytes / _mb).toStringAsFixed(1)} MB';
    }
    if (bytes >= _kb) {
      return '${(bytes / _kb).round()} KB';
    }
    return '$bytes B';
  }
}
