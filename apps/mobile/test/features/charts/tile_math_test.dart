import 'package:flutter_test/flutter_test.dart';

import 'package:navis_mobile/features/charts/data/tile_math.dart';

void main() {
  group('TileMath', () {
    test('projects known coordinates onto the slippy grid', () {
      expect(TileMath.tileX(0, 0), 0);
      expect(TileMath.tileY(0, 0), 0);
      // Cullera, where the blank-map report came from.
      expect(TileMath.tileX(-0.23, 14), 8181);
      expect(TileMath.tileY(39.16, 14), 6252);
      expect(TileMath.tileX(-0.23, 6), 31);
      expect(TileMath.tileY(39.16, 6), 24);
    });

    test('clamps past the projection limits instead of diverging', () {
      expect(TileMath.tileY(90, 4), 0);
      expect(TileMath.tileY(-90, 4), 15);
      expect(TileMath.tileX(-180, 4), 0);
      expect(TileMath.tileX(180, 4), 15);
    });

    test('orders the range whichever way the box was built', () {
      const box = (west: -0.25, south: 39.14, east: -0.21, north: 39.18);
      final range = TileMath.range(box, 12);
      expect(range.minX, lessThanOrEqualTo(range.maxX));
      // Rows grow southward: the northern edge is the smaller row index.
      expect(range.minY, TileMath.tileY(box.north, 12));
      expect(range.maxY, TileMath.tileY(box.south, 12));
    });

    test('counts exactly what it enumerates', () {
      const box = (west: -0.6, south: 39.0, east: -0.1, north: 39.4);
      expect(
        TileMath.tiles(box, 6, 11).length,
        TileMath.countTiles(box, 6, 11),
      );
    });

    test('enumerates shallowest zoom first, so a stop leaves wide coverage',
        () {
      const box = (west: -0.25, south: 39.14, east: -0.21, north: 39.18);
      final zooms = TileMath.tiles(box, 6, 9).map((t) => t.z).toList();
      expect(zooms.first, 6);
      expect(zooms.last, 9);
      expect(zooms, orderedEquals(List<int>.from(zooms)..sort()));
    });
  });
}
