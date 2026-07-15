import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/database/mutation_queue.dart';
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
      Directory.systemTemp.createTempSync('navis_mq_test').path,
    );
    // Replay goes through ApiClient.instance, whose auth interceptor
    // reads the Supabase session.
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

  group('enqueue', () {
    test('persists method, path and body and bumps the pending count',
        () async {
      final queue = container.read(mutationQueueProvider.notifier);

      await queue.enqueue(
        method: 'POST',
        path: '/api/v1/boats/boat-1/documents',
        body: {'type': 'itb'},
      );
      await queue.enqueue(method: 'DELETE', path: '/api/v1/documents/d9');

      final rows = await db.getPendingMutations();
      expect(rows, hasLength(2));
      expect(rows.first['method'], 'POST');
      expect(rows.first['path'], '/api/v1/boats/boat-1/documents');
      expect(jsonDecode(rows.first['body'] as String), {'type': 'itb'});
      expect(rows.first['retry_count'], 0);
      expect(rows.first['created_at'], isNotNull);
      expect(rows.last['method'], 'DELETE');
      expect(rows.last['body'], isNull);
      expect(container.read(mutationQueueProvider), 2);
    });

    test('the pending count is restored from disk on creation', () async {
      await db.insertMutation({
        'id': 'm-1',
        'method': 'POST',
        'path': '/api/v1/boats',
        'body': null,
        'created_at': DateTime(2026, 7).toIso8601String(),
        'retry_count': 0,
      });

      container.read(mutationQueueProvider.notifier);

      await eventually(() => container.read(mutationQueueProvider) == 1);
    });
  });

  group('replayAll', () {
    test('sends queued mutations to the API in FIFO order and clears them',
        () async {
      final queue = container.read(mutationQueueProvider.notifier);
      await queue.enqueue(method: 'POST', path: '/a', body: {'n': 1});
      await queue.enqueue(method: 'PUT', path: '/b', body: {'n': 2});
      await queue.enqueue(method: 'DELETE', path: '/c');

      await queue.replayAll();

      expect(
        adapter.requests.map((r) => '${r.method} ${r.path}').toList(),
        ['POST /a', 'PUT /b', 'DELETE /c'],
      );
      expect(adapter.requests[1].data, {'n': 2});
      expect(await db.getPendingMutations(), isEmpty);
      expect(container.read(mutationQueueProvider), 0);
    });

    test(
        'a failed mutation is kept with a bumped retry count and the '
        'rest still replays', () async {
      adapter.handler = (options) => options.path == '/fail'
          ? jsonResponseBody('{"error":"boom"}', statusCode: 400)
          : jsonResponseBody('{"data":{}}');
      final queue = container.read(mutationQueueProvider.notifier);
      await queue.enqueue(method: 'POST', path: '/fail', body: {'n': 1});
      await queue.enqueue(method: 'POST', path: '/ok', body: {'n': 2});

      // Incurs the queue's fixed 2s backoff after the failure.
      await queue.replayAll();

      expect(adapter.requests, hasLength(2));
      final rows = await db.getPendingMutations();
      expect(rows, hasLength(1));
      expect(rows.single['path'], '/fail');
      expect(rows.single['retry_count'], 1);
      expect(container.read(mutationQueueProvider), 1);
    });

    test('stops replaying after a failure once connectivity drops', () async {
      adapter.handler = (options) {
        connectivity.setOnline(false);
        return jsonResponseBody('{"error":"gone"}', statusCode: 400);
      };
      final queue = container.read(mutationQueueProvider.notifier);
      await queue.enqueue(method: 'POST', path: '/one', body: {'n': 1});
      await queue.enqueue(method: 'POST', path: '/two', body: {'n': 2});

      await queue.replayAll();

      // Only the first mutation was attempted; both stay queued.
      expect(adapter.requests, hasLength(1));
      expect(await db.getPendingMutationCount(), 2);
      expect(container.read(mutationQueueProvider), 2);
    });

    test('an entry at the retry cap is dropped without being sent', () async {
      await db.insertMutation({
        'id': 'm-1',
        'method': 'POST',
        'path': '/never-sent',
        'body': null,
        'created_at': DateTime(2026, 7).toIso8601String(),
        'retry_count': 5,
      });
      final queue = container.read(mutationQueueProvider.notifier);

      await queue.replayAll();

      // Documents the actual semantics: after 5 failed retries the
      // mutation is deleted silently — the user's change is lost with
      // no error surfaced anywhere.
      expect(adapter.requests, isEmpty);
      expect(await db.getPendingMutationCount(), 0);
    });
  });
}
