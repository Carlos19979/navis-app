import 'package:navis_mobile/core/network/api_client.dart';
import 'package:navis_mobile/features/documents/data/models/document_model.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  @override
  Future<PaginatedResponse<Document>> getDocuments(
    String boatId, {
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    };

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/boats/$boatId/documents',
      queryParameters: queryParams,
    );

    final data = response.data!;
    final items = (data['items'] as List<dynamic>)
        .map((json) =>
            DocumentModel.fromJson(json as Map<String, dynamic>).toEntity())
        .toList();

    return PaginatedResponse<Document>(
      items: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  @override
  Future<Document> getDocument(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/documents/$id',
    );
    return DocumentModel.fromJson(response.data!).toEntity();
  }

  @override
  Future<Document> createDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/boats/${document.boatId}/documents',
      data: model.toJson(),
    );
    return DocumentModel.fromJson(response.data!).toEntity();
  }

  @override
  Future<Document> updateDocument(Document document) async {
    final model = DocumentModel.fromEntity(document);
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/documents/${document.id}',
      data: model.toJson(),
    );
    return DocumentModel.fromJson(response.data!).toEntity();
  }

  @override
  Future<void> deleteDocument(String id) async {
    await _apiClient.delete<void>('/api/v1/documents/$id');
  }
}
