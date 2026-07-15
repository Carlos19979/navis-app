import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:navis_mobile/core/database/local_database.dart';
import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/database/offline_repository.dart';
import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/documents/data/models/document_model.dart';
import 'package:navis_mobile/features/documents/data/repositories/document_repository.dart';

import '../../helpers/helpers.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLocalDatabase extends Mock implements LocalDatabase {}

class MockMutationQueue extends Mock implements MutationQueueNotifier {}

DioException networkError() => DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
    );

DioException badRequest() => DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 400,
      ),
    );

void main() {
  late MockApiClient api;
  late MockLocalDatabase db;
  late MockMutationQueue queue;
  late DocumentRepositoryImpl repo;

  setUp(() {
    api = MockApiClient();
    db = MockLocalDatabase();
    queue = MockMutationQueue();
    when(() => db.upsert(any(), any(), any(), boatId: any(named: 'boatId')))
        .thenAnswer((_) async {});
    when(() => db.deleteById(any(), any())).thenAnswer((_) async {});
    when(() => queue.enqueue(
          method: any(named: 'method'),
          path: any(named: 'path'),
          body: any(named: 'body'),
        )).thenAnswer((_) async {});
    repo = DocumentRepositoryImpl(
      apiClient: api,
      // Real OfflineRepository so the tests exercise the actual
      // isNetworkError classification; the db underneath is mocked.
      offlineRepo: OfflineRepository(db: db, isOnline: false),
      mutationQueue: queue,
    );
  });

  void verifyNothingEnqueued() {
    verifyNever(() => queue.enqueue(
          method: any(named: 'method'),
          path: any(named: 'path'),
          body: any(named: 'body'),
        ));
  }

  group('createDocument', () {
    test('enqueues and returns the document optimistically on a network error',
        () async {
      final doc = makeDocument();
      when(() =>
              api.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenThrow(networkError());

      final result = await repo.createDocument(doc);

      expect(result, same(doc));
      final body = verify(() => queue.enqueue(
            method: 'POST',
            path: '/api/v1/boats/boat-1/documents',
            body: captureAny(named: 'body'),
          )).captured.single as Map<String, dynamic>;
      expect(body['type'], 'Insurance');
      expect(body['boat_id'], 'boat-1');
      // Creates are not written to the local cache while offline.
      verifyNever(
        () => db.upsert(any(), any(), any(), boatId: any(named: 'boatId')),
      );
    });

    test('rethrows a non-network error without enqueueing', () async {
      when(() =>
              api.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenThrow(badRequest());

      await expectLater(
        repo.createDocument(makeDocument()),
        throwsA(isA<DioException>()),
      );

      verifyNothingEnqueued();
    });

    test('caches the server document and skips the queue on success', () async {
      final doc = makeDocument();
      final serverJson = DocumentModel.fromEntity(doc).toJson();
      when(() =>
              api.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/'),
          data: {'data': serverJson},
        ),
      );

      final result = await repo.createDocument(doc);

      expect(result.id, doc.id);
      verify(() => db.upsert('documents', doc.id, any(), boatId: 'boat-1'))
          .called(1);
      verifyNothingEnqueued();
    });
  });

  group('updateDocument', () {
    test(
        'enqueues, caches optimistically and returns the document on a '
        'network error', () async {
      final doc = makeDocument();
      when(() => api.put<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenThrow(networkError());

      final result = await repo.updateDocument(doc);

      expect(result, same(doc));
      verify(() => queue.enqueue(
            method: 'PUT',
            path: '/api/v1/documents/doc-1',
            body: any(named: 'body'),
          )).called(1);
      // The optimistic version is cached so offline reads see the edit.
      verify(() => db.upsert('documents', 'doc-1', any(), boatId: 'boat-1'))
          .called(1);
    });

    test('rethrows a non-network error without enqueueing or caching',
        () async {
      when(() => api.put<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenThrow(badRequest());

      await expectLater(
        repo.updateDocument(makeDocument()),
        throwsA(isA<DioException>()),
      );

      verifyNothingEnqueued();
      verifyNever(
        () => db.upsert(any(), any(), any(), boatId: any(named: 'boatId')),
      );
    });
  });

  group('deleteDocument', () {
    test('enqueues and drops the cached copy on a network error', () async {
      when(() => api.delete<void>(any())).thenThrow(networkError());

      await repo.deleteDocument('doc-1');

      verify(() => queue.enqueue(
            method: 'DELETE',
            path: '/api/v1/documents/doc-1',
          )).called(1);
      verify(() => db.deleteById('documents', 'doc-1')).called(1);
    });

    test('rethrows a non-network error without enqueueing', () async {
      when(() => api.delete<void>(any())).thenThrow(badRequest());

      await expectLater(
        repo.deleteDocument('doc-1'),
        throwsA(isA<DioException>()),
      );

      verifyNothingEnqueued();
      verifyNever(() => db.deleteById(any(), any()));
    });
  });

  test('a repository without offline wiring rethrows network errors', () async {
    final bare = DocumentRepositoryImpl(apiClient: api);
    when(() => api.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(networkError());

    await expectLater(
      bare.createDocument(makeDocument()),
      throwsA(isA<DioException>()),
    );
  });
}
