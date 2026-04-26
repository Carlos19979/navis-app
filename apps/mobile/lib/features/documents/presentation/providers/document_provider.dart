import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/features/documents/data/repositories/document_repository.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl();
});

final boatDocumentsProvider =
    FutureProvider.family<List<Document>, String>((ref, boatId) async {
  final repository = ref.watch(documentRepositoryProvider);
  final response = await repository.getDocuments(boatId);
  return response.items;
});

final documentProvider =
    FutureProvider.family<Document, String>((ref, id) async {
  final repository = ref.watch(documentRepositoryProvider);
  return repository.getDocument(id);
});

final createDocumentProvider =
    FutureProvider.family<Document, Document>((ref, document) async {
  final repository = ref.read(documentRepositoryProvider);
  final created = await repository.createDocument(document);
  ref.invalidate(boatDocumentsProvider(document.boatId));
  return created;
});

final deleteDocumentProvider =
    FutureProvider.family<void, ({String id, String boatId})>(
        (ref, params) async {
  final repository = ref.read(documentRepositoryProvider);
  await repository.deleteDocument(params.id);
  ref.invalidate(boatDocumentsProvider(params.boatId));
});
