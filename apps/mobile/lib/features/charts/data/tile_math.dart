import 'dart:math' as math;

/// A single slippy-map tile address.
typedef TileRef = ({int z, int x, int y});

/// A geographic box, west/south/east/north in degrees.
typedef TileBox = ({double west, double south, double east, double north});

/// Slippy-map (Web Mercator) tile arithmetic, shared by the offline tile store
/// — which pins whole regions — and the region downloader, which enumerates
/// them. Kept apart from both so the two always agree on what "the tiles of
/// this box" means.
abstract final class TileMath {
  /// Tile column containing [lon] at zoom [z].
  static int tileX(double lon, int z) {
    final n = 1 << z;
    final x = ((lon + 180) / 360 * n).floor();
    return _clampInt(x, 0, n - 1);
  }

  /// Tile row containing [lat] at zoom [z].
  static int tileY(double lat, int z) {
    final n = 1 << z;
    // Beyond the Mercator limit the projection diverges; clamp instead.
    final lat0 = math.min(math.max(lat, -85.05112878), 85.05112878);
    final rad = lat0 * math.pi / 180;
    final mercator = math.log(math.tan(rad) + 1 / math.cos(rad));
    final y = ((1 - mercator / math.pi) / 2 * n).floor();
    return _clampInt(y, 0, n - 1);
  }

  /// Inclusive tile index range covering [box] at zoom [z].
  static ({int minX, int maxX, int minY, int maxY}) range(TileBox box, int z) {
    final x1 = tileX(box.west, z);
    final x2 = tileX(box.east, z);
    // Latitude grows northward, tile rows grow southward.
    final y1 = tileY(box.north, z);
    final y2 = tileY(box.south, z);
    return (
      minX: math.min(x1, x2),
      maxX: math.max(x1, x2),
      minY: math.min(y1, y2),
      maxY: math.max(y1, y2),
    );
  }

  /// How many tiles one layer needs to cover [box] from [minZoom] to
  /// [maxZoom]. Cheap enough to call on every rebuild of the download sheet.
  static int countTiles(TileBox box, int minZoom, int maxZoom) {
    var total = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final r = range(box, z);
      total += (r.maxX - r.minX + 1) * (r.maxY - r.minY + 1);
    }
    return total;
  }

  /// Every tile of [box] between [minZoom] and [maxZoom], shallowest first so
  /// an interrupted download still leaves usable wide-area coverage.
  static Iterable<TileRef> tiles(TileBox box, int minZoom, int maxZoom) sync* {
    for (var z = minZoom; z <= maxZoom; z++) {
      final r = range(box, z);
      for (var x = r.minX; x <= r.maxX; x++) {
        for (var y = r.minY; y <= r.maxY; y++) {
          yield (z: z, x: x, y: y);
        }
      }
    }
  }

  static int _clampInt(int value, int min, int max) =>
      math.min(math.max(value, min), max);
}
