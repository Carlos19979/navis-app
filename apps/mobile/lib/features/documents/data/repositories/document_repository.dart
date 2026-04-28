import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/documents/data/models/document_model.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  static final Map<String, List<Document>> _cachedDocuments = {};

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
      final items = (envelope['data'] as List<dynamic>)
          .map((json) =>
              DocumentModel.fromJson(json as Map<String, dynamic>)
                  .toEntity())
          .toList();
      final meta = envelope['meta'] as Map<String, dynamic>?;

      if (cursor == null) {
        _cachedDocuments[boatId] = items;
      }

      return PaginatedResponse<Document>(
        items: items,
        nextCursor: meta?['next_cursor'] as String?,
      );
    } catch (e) {
      if (_cachedDocuments.containsKey(boatId) &&
          cursor == null) {
        return PaginatedResponse<Document>(
          items: _cachedDocuments[boatId]!,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Document> getDocument(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/documents/$id',
    );
    final envelope = response.data!;
    return DocumentModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  @override
  Future<Document> createDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/${document.boatId}/documents',
      data: model.toJson(),
    );
    final envelope = response.data!;
    return DocumentModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  @override
  Future<Document> updateDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/documents/${document.id}',
      data: model.toJson(),
    );
    final envelope = response.data!;
    return DocumentModel.fromJson(
      envelope['data'] as Map<String, dynamic>,
    ).toEntity();
  }

  @override
  Future<void> deleteDocument(String id) async {
    await _apiClient.delete<void>('/api/v1/documents/$id');
  }
}
