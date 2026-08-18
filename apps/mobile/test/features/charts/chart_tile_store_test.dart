import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_store.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';

import '../../helpers/local_db.dart';

/// A small box off Cullera, the area the blank-map report came from.
const _box = (west: -0.25, south: 39.14, east: -0.21, north: 39.18);

/// Inside [_box] at zoom 7, and a tile on the other side of the world.
const _inside = (z: 7, x: 63, y: 48);
const _outside = (z: 7, x: 0, y: 0);

ChartRegion _region({
  String id = 'r1',
  int minZoom = 6,
  int maxZoom = 8,
  ChartRegionStatus status = ChartRegionStatus.ready,
}) {
  return ChartRegion(
    id: id,
    name: 'Cullera',
    west: _box.west,
    south: _box.south,
    east: _box.east,
    north: _box.north,
    minZoom: minZoom,
    maxZoom: maxZoom,
    createdAt: DateTime(2026, 8, 18),
    status: status,
  );
}

Uint8List _bytes(int n) => Uint8List.fromList(List<int>.filled(n, 7));

void main() {
  const dbName = 'chart_tiles_test.db';
  late ChartTileStore store;

  setUpAll(() async {
    await useIsolatedDatabase('chart_tile_store');
  });

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, dbName));
    store = ChartTileStore(databaseName: dbName);
  });

  tearDown(() async {
    await store.close();
  });

  test('stores and returns tile bytes', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(64));

    final stored = await store.lookup(ChartTileLayer.base, _inside);
    expect(stored, isNotNull);
    expect(stored!.bytes, hasLength(64));
    expect(stored.isBlank, isFalse);
    expect(stored.pinned, isFalse);
    expect(await store.has(ChartTileLayer.base, _inside), isTrue);
  });

  test('keeps the layers apart', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(64));
    expect(await store.has(ChartTileLayer.seamark, _inside), isFalse);
    expect(await store.lookup(ChartTileLayer.seamark, _inside), isNull);
  });

  test('remembers empty water, so it is never requested twice', () async {
    await store.save(ChartTileLayer.seamark, _inside, Uint8List(0));

    final stored = await store.lookup(ChartTileLayer.seamark, _inside);
    expect(stored, isNotNull);
    expect(stored!.isBlank, isTrue);
    expect(stored.bytes, isNull);
  });

  test('pins the tiles a saved region covers, and only those', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(64));
    await store.save(ChartTileLayer.base, _outside, _bytes(64));

    await store.saveRegion(_region());

    final inside = await store.lookup(ChartTileLayer.base, _inside);
    final outside = await store.lookup(ChartTileLayer.base, _outside);
    expect(inside!.pinned, isTrue, reason: 'downloaded area must survive');
    expect(outside!.pinned, isFalse);
  });

  test('pins tiles stored while browsing, not just downloaded ones', () async {
    // The download skips tiles already on disk; pinning is derived from the
    // region afterwards, so those tiles are protected all the same.
    await store.saveRegion(_region());
    await store.save(ChartTileLayer.base, _inside, _bytes(64));
    await store.saveRegion(_region());

    final stored = await store.lookup(ChartTileLayer.base, _inside);
    expect(stored!.pinned, isTrue);
  });

  test('eviction drops aged browse tiles and never pinned ones', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(64));
    await store.save(ChartTileLayer.base, _outside, _bytes(64));
    await store.saveRegion(_region());

    // Age both tiles past the browse window.
    final db = await store.database;
    await db.update('tiles', {
      'fetched_at': DateTime(2020).millisecondsSinceEpoch,
      'last_used': DateTime(2020).millisecondsSinceEpoch,
    });

    await store.pruneBrowseCache();

    expect(await store.has(ChartTileLayer.base, _inside), isTrue);
    expect(await store.has(ChartTileLayer.base, _outside), isFalse);
  });

  test('reports the region size from what is actually on disk', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(100));
    await store.save(ChartTileLayer.seamark, _inside, _bytes(40));
    await store.save(ChartTileLayer.base, _outside, _bytes(1000));

    final usage = await store.regionUsage(_region());
    expect(usage.tiles, 2);
    expect(usage.bytes, 140);
    expect(await store.totalBytes(), 1140);
    expect(await store.pinnedBytes(), 0);
  });

  test('deleting a region frees its tiles but not the browse cache', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(64));
    await store.save(ChartTileLayer.base, _outside, _bytes(64));
    await store.saveRegion(_region());

    await store.deleteRegion('r1');

    expect(await store.regions(), isEmpty);
    expect(await store.has(ChartTileLayer.base, _inside), isFalse);
    expect(await store.has(ChartTileLayer.base, _outside), isTrue);
  });

  test('a tile shared with another region survives the delete', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(64));
    await store.saveRegion(_region());
    await store.saveRegion(_region(id: 'r2'));

    await store.deleteRegion('r1');

    final stored = await store.lookup(ChartTileLayer.base, _inside);
    expect(stored, isNotNull);
    expect(stored!.pinned, isTrue);
  });

  test('a failed region protects nothing', () async {
    await store.save(ChartTileLayer.base, _inside, _bytes(64));
    await store.saveRegion(_region(status: ChartRegionStatus.failed));

    final stored = await store.lookup(ChartTileLayer.base, _inside);
    expect(stored!.pinned, isFalse);
  });

  test('round-trips a region row', () async {
    await store.saveRegion(_region(maxZoom: 14).copyWith(bytes: 4096));

    final regions = await store.regions();
    expect(regions, hasLength(1));
    expect(regions.single.name, 'Cullera');
    expect(regions.single.maxZoom, 14);
    expect(regions.single.bytes, 4096);
    expect(regions.single.status, ChartRegionStatus.ready);
    expect(regions.single.createdAt, DateTime(2026, 8, 18));
  });

  test('the pinned box matches the tile arithmetic', () async {
    // Guards the two places that must agree: what the downloader fetches and
    // what the store protects.
    final range = TileMath.range(_box, 7);
    expect(_inside.x, inInclusiveRange(range.minX, range.maxX));
    expect(_inside.y, inInclusiveRange(range.minY, range.maxY));
  });
}
