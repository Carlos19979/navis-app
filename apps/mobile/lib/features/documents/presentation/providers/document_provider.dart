import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navis_mobile/core/database/mutation_queue.dart';
import 'package:navis_mobile/core/utils/navis_date_utils.dart';
import 'package:navis_mobile/core/database/offline_repository.dart';
import 'package:navis_mobile/features/documents/data/repositories/document_repository.dart';
import 'package:navis_mobile/features/documents/domain/entities/document.dart';
import 'package:navis_mobile/features/documents/domain/repositories/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(
    offlineRepo: ref.watch(offlineRepositoryProvider),
    mutationQueue: ref.watch(mutationQueueProvider.notifier),
  );
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

class DocumentSummary {
  const DocumentSummary({
    this.total = 0,
    this.expired = 0,
    this.critical = 0,
    this.warning = 0,
    this.ok = 0,
  });

  final int total;
  final int expired;
  final int critical;
  final int warning;
  final int ok;
}

final boatDocumentSummaryProvider =
    FutureProvider.family<DocumentSummary, String>((ref, boatId) async {
  final docs = await ref.watch(boatDocumentsProvider(boatId).future);
  var expired = 0;
  var critical = 0;
  var warning = 0;
  var ok = 0;

  for (final doc in docs) {
    switch (NavisDateUtils.statusFor(doc.expiryDate)) {
      case DocExpiryStatus.expired:
        expired++;
      case DocExpiryStatus.critical:
        critical++;
      case DocExpiryStatus.warning:
        warning++;
      case DocExpiryStatus.ok:
        ok++;
    }
  }

  return DocumentSummary(
    total: docs.length,
    expired: expired,
    critical: critical,
    warning: warning,
    ok: ok,
  );
});
