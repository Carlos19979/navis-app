import 'package:navis_mobile/core/database/offline_repository.dart';
import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/documents/data/models/document_model.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    ApiClient? apiClient,
    this.offlineRepo,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;
  final OfflineRepository? offlineRepo;

  @override
  Future<PaginatedResponse<Document>> getDocuments(
    String boatId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      };

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/boats/$boatId/documents',
        queryParameters: queryParams,
      );

      final envelope = response.data!;
      final dataList = envelope['data'] as List<dynamic>;
      final items = dataList
          .map((json) =>
              DocumentModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();
      final meta = envelope['meta'] as Map<String, dynamic>?;

      if (cursor == null && offlineRepo != null) {
        await offlineRepo!.cacheList(
          'documents',
          dataList.cast<Map<String, dynamic>>(),
          boatId: boatId,
        );
      }

      return PaginatedResponse<Document>(
        items: items,
        nextCursor: meta?['next_cursor'] as String?,
      );
    } catch (e) {
      if (offlineRepo != null &&
          cursor == null &&
          offlineRepo!.isNetworkError(e)) {
        final cached = await offlineRepo!.getCachedByBoat(
          'documents',
          boatId,
        );
        if (cached.isNotEmpty) {
          return PaginatedResponse<Document>(
            items: cached
                .map((j) => DocumentModel.fromJson(j).toEntity())
                .toList(),
          );
        }
      }
      rethrow;
    }
  }

  @override
  Future<Document> getDocument(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/documents/$id',
      );
      final envelope = response.data!;
      final data = envelope['data'] as Map<String, dynamic>;

      if (offlineRepo != null) {
        await offlineRepo!.cacheItem('documents', id, data);
      }

      return DocumentModel.fromJson(data).toEntity();
    } catch (e) {
      if (offlineRepo != null && offlineRepo!.isNetworkError(e)) {
        final cached = await offlineRepo!.getCachedById('documents', id);
        if (cached != null) {
          return DocumentModel.fromJson(cached).toEntity();
        }
      }
      rethrow;
    }
  }

  @override
  Future<Document> createDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/${document.boatId}/documents',
      data: model.toJson(),
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;

    if (offlineRepo != null) {
      await offlineRepo!.cacheItem(
        'documents',
        data['id'] as String,
        data,
        boatId: document.boatId,
      );
    }

    return DocumentModel.fromJson(data).toEntity();
  }

  @override
  Future<Document> updateDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/documents/${document.id}',
      data: model.toJson(),
    );
    final envelope = response.data!;
    final data = envelope['data'] as Map<String, dynamic>;

    if (offlineRepo != null) {
      await offlineRepo!.cacheItem(
        'documents',
        document.id,
        data,
        boatId: document.boatId,
      );
    }

    return DocumentModel.fromJson(data).toEntity();
  }

  @override
  Future<void> deleteDocument(String id) async {
    await _apiClient.delete<void>('/api/v1/documents/$id');

    if (offlineRepo != null) {
      await offlineRepo!.removeItem('documents', id);
    }
  }
}
