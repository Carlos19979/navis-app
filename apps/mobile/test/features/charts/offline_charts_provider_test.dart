import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:navis_mobile/core/network/connectivity_provider.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_layer.dart';
import 'package:navis_mobile/features/charts/data/chart_tile_store.dart';
import 'package:navis_mobile/features/charts/domain/entities/chart_region.dart';
import 'package:navis_mobile/features/charts/presentation/providers/offline_charts_provider.dart';

import '../../helpers/local_db.dart';
import '../../helpers/offline.dart';

const _inside = (z: 7, x: 63, y: 48);

ChartRegion _region({
  required String id,
  int maxZoom = 14,
  ChartRegionStatus status = ChartRegionStatus.ready,
}) {
  return ChartRegion(
    id: id,
    name: id,
    west: -0.25,
    south: 39.14,
    east: -0.21,
    north: 39.18,
    minZoom: 6,
    maxZoom: maxZoom,
    createdAt: DateTime(2026, 8, 18),
    status: status,
  );
}

void main() {
  const dbName = 'offline_charts_provider_test.db';
  late ChartTileStore store;
  late FakeConnectivityNotifier connectivity;
  late ProviderContainer container;

  setUpAll(() async {
    await useIsolatedDatabase('offline_charts_provider');
  });

  setUp(() async {
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, dbName));
    store = ChartTileStore(databaseName: dbName);
    connectivity = FakeConnectivityNotifier();
    container = ProviderContainer(overrides: [
      chartTileStoreProvider.overrideWithValue(store),
      connectivityProvider.overrideWith((ref) => connectivity),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
  });

  test('online, the tile layers are left at full detail', () async {
    await store.saveRegion(_region(id: 'r1'));
    await container.read(chartRegionsProvider.future);

    expect(container.read(offlineChartZoomProvider), isNull);
  });

  test('offline, clamps to the shallowest region on the device', () async {
    await store.saveRegion(_region(id: 'deep', maxZoom: 16));
    await store.saveRegion(_region(id: 'shallow', maxZoom: 12));
    await container.read(chartRegionsProvider.future);

    connectivity.setOnline(false);

    // 12, not 16: the guarantee has to hold in the shallowest region too, or
    // zooming in there goes blank again.
    expect(container.read(offlineChartZoomProvider), 12);
  });

  test('offline with nothing saved leaves the layers alone', () async {
    await container.read(chartRegionsProvider.future);
    connectivity.setOnline(false);

    expect(container.read(offlineChartZoomProvider), isNull);
  });

  test('a failed region is not treated as coverage', () async {
    await store.saveRegion(
      _region(id: 'r1', status: ChartRegionStatus.failed),
    );
    await container.read(chartRegionsProvider.future);
    connectivity.setOnline(false);

    expect(container.read(offlineChartZoomProvider), isNull);
  });

  test('deleting a region drops it from the list and frees its tiles',
      () async {
    await store.save(
      ChartTileLayer.base,
      _inside,
      Uint8List.fromList(List<int>.filled(32, 1)),
    );
    await store.saveRegion(_region(id: 'r1'));
    await container.read(chartRegionsProvider.future);

    await container.read(chartRegionsProvider.notifier).delete('r1');

    expect(container.read(chartRegionsProvider).valueOrNull, isEmpty);
    expect(await store.has(ChartTileLayer.base, _inside), isFalse);
  });

  test('reports the storage the charts occupy', () async {
    await store.save(
      ChartTileLayer.base,
      _inside,
      Uint8List.fromList(List<int>.filled(2048, 1)),
    );

    expect(await container.read(chartStorageBytesProvider.future), 2048);
  });
}
