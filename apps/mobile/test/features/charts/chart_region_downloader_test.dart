import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:navis_mobile/features/charts/data/chart_region_downloader.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_fetcher.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_store.dart';
import 'package:navis_mobile/features/charts/data/tile_math.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';

import '../../helpers/local_db.dart';

/// Records what was asked for and answers without a network.
class _FakeFetcher extends ChartTileFetcher {
  _FakeFetcher({this.alwaysFails = false});

  final List<String> requested = [];
  bool alwaysFails;

  @override
  Future<Uint8List> fetch(
    ChartTileLayer layer,
    TileRef ref, {
    Map<String, String>? headers,
  }) async {
    requested.add('${layer.id}/${ref.z}/${ref.x}/${ref.y}');
    if (alwaysFails) throw Exception('no route to host');
    return Uint8List.fromList(List<int>.filled(10, 3));
  }
}

/// Two zoom levels over a box small enough to be one tile per level: four
/// tiles once both layers are counted.
ChartRegion _region({int minZoom = 6, int maxZoom = 7}) => ChartRegion(
      id: 'r1',
      name: 'Cullera',
      west: -0.25,
      south: 39.14,
      east: -0.21,
      north: 39.18,
      minZoom: minZoom,
      maxZoom: maxZoom,
      createdAt: DateTime(2026, 8, 18),
    );

void main() {
  const dbName = 'chart_downloader_test.db';
  late ChartTileStore store;
  late _FakeFetcher fetcher;

  setUpAll(() async {
    await useIsolatedDatabase('chart_region_downloader');
  });

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, dbName));
    store = ChartTileStore(databaseName: dbName);
    fetcher = _FakeFetcher();
  });

  tearDown(() async {
    await store.close();
  });

  ChartRegionDownloader downloader() => ChartRegionDownloader(
        store: store,
        fetcher: fetcher,
        concurrency: 2,
      );

  test('stores both layers at every zoom and marks the region ready', () async {
    final tallies = <ChartDownloadTally>[];

    final outcome = await downloader().download(
      _region(),
      onProgress: tallies.add,
    );

    expect(outcome, ChartDownloadOutcome.completed);
    expect(fetcher.requested, hasLength(4));
    expect(await store.has(ChartTileLayer.base, (z: 6, x: 31, y: 24)), isTrue);
    expect(
      await store.has(ChartTileLayer.seamark, (z: 7, x: 63, y: 48)),
      isTrue,
    );

    final saved = await store.regions();
    expect(saved.single.status, ChartRegionStatus.ready);
    expect(saved.single.tileCount, 4);
    expect(saved.single.bytes, 40);

    expect(tallies, isNotEmpty);
    expect(tallies.last.done, 4);
    expect(tallies.last.total, 4);
  });

  test('pins what it stored, so browsing cannot evict it', () async {
    await downloader().download(_region(), onProgress: (_) {});

    final stored =
        await store.lookup(ChartTileLayer.base, (z: 7, x: 63, y: 48));
    expect(stored!.pinned, isTrue);
  });

  test('a second run resumes instead of re-fetching', () async {
    await downloader().download(_region(), onProgress: (_) {});
    fetcher.requested.clear();

    final outcome = await downloader().download(_region(), onProgress: (_) {});

    expect(outcome, ChartDownloadOutcome.completed);
    expect(fetcher.requested, isEmpty);
  });

  test('cancelling keeps the tiles already saved', () async {
    var calls = 0;
    final outcome = await downloader().download(
      _region(maxZoom: 9),
      onProgress: (_) {},
      // Cancel as soon as the first worker asks a second time.
      isCancelled: () => ++calls > 2,
    );

    const box = (west: -0.25, south: 39.14, east: -0.21, north: 39.18);
    final everyTile = TileMath.countTiles(box, 6, 9) * 2;

    expect(outcome, ChartDownloadOutcome.cancelled);
    expect(fetcher.requested.length, lessThan(everyTile));
    final saved = await store.regions();
    expect(saved.single.status, ChartRegionStatus.ready);
  });

  test('a download that stores nothing is marked failed', () async {
    fetcher.alwaysFails = true;

    await downloader().download(_region(), onProgress: (_) {});

    final saved = await store.regions();
    expect(saved.single.status, ChartRegionStatus.failed);
    expect(saved.single.tileCount, 0);
  });

  test('estimates before downloading, both layers counted', () {
    const box = (west: -0.25, south: 39.14, east: -0.21, north: 39.18);
    expect(ChartRegionDownloader.plannedTileCount(box, 7), 4);
    expect(
      ChartRegionDownloader.estimatedBytes(box, 7),
      4 * ChartRegionDownloader.estimatedTileBytes,
    );
  });
}
