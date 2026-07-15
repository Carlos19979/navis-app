import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/database/sync_service.dart';
import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/core/network/connectivity_provider.dart';

import '../helpers/helpers.dart';

void main() {
  late LocalDatabase db;
  late ProviderContainer container;
  late FakeConnectivityNotifier connectivity;
  late RecordingHttpAdapter adapter;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Own directory so this suite's navis_cache.db never clashes with
    // other test files running in parallel isolates.
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('navis_sync_test').path,
    );
    await initFakeSupabase();
  });

  setUp(() {
    db = LocalDatabase();
    connectivity = FakeConnectivityNotifier();
    adapter = RecordingHttpAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
    container = ProviderContainer(overrides: [
      localDatabaseProvider.overrideWithValue(db),
      connectivityProvider.overrideWith((ref) => connectivity),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, 'navis_cache.db'));
  });

  // The offline -> online replay trigger is NOT wired in SyncService: it
  // lives in the mutationQueueProvider body, which listens to
  // connectivityProvider. These tests cover that seam with the real
  // provider graph.
  group('connectivity-driven replay', () {
    test('flipping offline -> online replays the pending queue', () async {
      final queue = container.read(mutationQueueProvider.notifier);
      await queue.enqueue(
        method: 'POST',
        path: '/api/v1/boats',
        body: {'name': 'Luna'},
      );

      connectivity.setOnline(false);
      connectivity.setOnline(true);

      await eventually(() => adapter.requests.isNotEmpty);
      await eventually(() => container.read(mutationQueueProvider) == 0);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/v1/boats');
      expect(await db.getPendingMutationCount(), 0);
    });

    test('going offline alone does not replay', () async {
      final queue = container.read(mutationQueueProvider.notifier);
      await queue.enqueue(method: 'POST', path: '/api/v1/boats');

      connectivity.setOnline(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(adapter.requests, isEmpty);
      expect(await db.getPendingMutationCount(), 1);
    });
  });

  group('SyncService.syncAll', () {
    test('is a no-op while offline', () async {
      connectivity.setOnline(false);
      final sync = container.read(syncServiceProvider);

      await sync.syncAll();

      expect(adapter.requests, isEmpty);
      expect(await db.getSyncMeta('last_sync'), isNull);
    });

    test(
        'on a cold cache: boats are cached, documents are NOT fetched '
        'yet, last_sync is stamped', () async {
      adapter.handler = (options) => switch (options.path) {
            '/api/v1/boats' => jsonResponseBody(jsonEncode({
                'data': [
                  {'id': 'b1', 'name': 'Luna'},
                ],
              })),
            '/api/v1/boats/b1/documents' => jsonResponseBody(jsonEncode({
                'data': [
                  {'id': 'd1', 'type': 'itb'},
                ],
              })),
            _ => jsonResponseBody('{"data":[]}'),
          };
      final sync = container.read(syncServiceProvider);

      await sync.syncAll();

      final boats = await db.getAll('boats');
      expect(boats, hasLength(1));
      expect(jsonDecode(boats.single)['id'], 'b1');
      // Documents the actual semantics: _syncBoats and _syncDocuments
      // run concurrently (Future.wait), so the document pass iterates
      // the boats cache as of BEFORE this sync — on a first-ever sync
      // no documents are fetched until the next syncAll.
      expect(await db.getByBoatId('documents', 'b1'), isEmpty);
      expect(await db.getSyncMeta('last_sync'), isNotNull);
    });

    test('caches documents for boats already in the local cache', () async {
      await db.upsert(
        'boats',
        'b1',
        jsonEncode({'id': 'b1', 'name': 'Luna'}),
      );
      adapter.handler = (options) => switch (options.path) {
            '/api/v1/boats' => jsonResponseBody(jsonEncode({
                'data': [
                  {'id': 'b1', 'name': 'Luna'},
                ],
              })),
            '/api/v1/boats/b1/documents' => jsonResponseBody(jsonEncode({
                'data': [
                  {'id': 'd1', 'type': 'itb'},
                ],
              })),
            _ => jsonResponseBody('{"data":[]}'),
          };
      final sync = container.read(syncServiceProvider);

      await sync.syncAll();

      final docs = await db.getByBoatId('documents', 'b1');
      expect(docs, hasLength(1));
      expect(jsonDecode(docs.single)['id'], 'd1');
    });

    test('swallows API errors — and still stamps last_sync', () async {
      adapter.handler =
          (_) => jsonResponseBody('{"error":"boom"}', statusCode: 400);
      final sync = container.read(syncServiceProvider);

      await sync.syncAll();

      expect(await db.getAll('boats'), isEmpty);
      // Documents the actual semantics: each sync step swallows its own
      // errors, so last_sync is stamped even when nothing was synced.
      expect(await db.getSyncMeta('last_sync'), isNotNull);
    });
  });

  group('SyncService.syncTripsForBoat', () {
    test('is a no-op while offline', () async {
      connectivity.setOnline(false);
      final sync = container.read(syncServiceProvider);

      await sync.syncTripsForBoat('b1');

      expect(adapter.requests, isEmpty);
    });

    test('caches the trips of the boat', () async {
      adapter.handler = (options) => jsonResponseBody(jsonEncode({
            'data': [
              {'id': 't1'},
              {'id': 't2'},
            ],
          }));
      final sync = container.read(syncServiceProvider);

      await sync.syncTripsForBoat('b1');

      expect(adapter.requests.single.path, '/api/v1/boats/b1/trips');
      expect(await db.getByBoatId('trips', 'b1'), hasLength(2));
    });
  });
}
