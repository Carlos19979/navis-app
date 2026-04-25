import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

abstract class DocumentRepository {
  Future<PaginatedResponse<Document>> getDocuments(
    String boatId, {
    String? cursor,
    int limit = 20,
  });
  Future<Document> getDocument(String id);
  Future<Document> createDocument(Document document);
  Future<Document> updateDocument(Document document);
  Future<void> deleteDocument(String id);
}
