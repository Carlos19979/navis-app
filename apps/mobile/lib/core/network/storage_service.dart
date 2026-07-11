import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:navis_mobile/core/network/supabase_client.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Signed URL for a private documents-bucket file (stored URL or path).
/// Null while signing fails (offline); public-bucket URLs pass through.
final signedDocumentUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, urlOrPath) {
  return ref.watch(storageServiceProvider).signedDocumentUrl(urlOrPath);
});

class StorageService {
  final uploadProgress = ValueNotifier<double?>(null);

  /// Signed-URL cache: storage path → (url, expiry). Entries are reused until
  /// shortly before they expire.
  final _signedCache = <String, ({String url, DateTime expiresAt})>{};

  static const _signedUrlTtl = Duration(hours: 1);
  static const _signedUrlSlack = Duration(minutes: 5);

  /// Resolves a display/download URL for a file in the private `documents`
  /// bucket. Accepts either a raw storage path or the public-style URL stored
  /// in the API (the stable identifier documents keep pointing at), extracts
  /// the path, and mints a signed URL (1h TTL, cached). URLs from other
  /// (public) buckets are returned unchanged. Returns null when signing fails
  /// (e.g. offline).
  Future<String?> signedDocumentUrl(String urlOrPath) async {
    final path = _documentsPathFrom(urlOrPath);
    if (path == null) return urlOrPath; // not a documents-bucket URL

    final cached = _signedCache[path];
    if (cached != null &&
        cached.expiresAt.isAfter(DateTime.now().add(_signedUrlSlack))) {
      return cached.url;
    }

    try {
      final signed = await supabaseClient.storage
          .from('documents')
          .createSignedUrl(path, _signedUrlTtl.inSeconds);
      _signedCache[path] = (
        url: signed,
        expiresAt: DateTime.now().add(_signedUrlTtl),
      );
      return signed;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the storage path from a documents-bucket URL, or returns the
  /// input verbatim when it's already a bare path. Returns null for URLs that
  /// don't belong to the documents bucket.
  String? _documentsPathFrom(String urlOrPath) {
    if (!urlOrPath.contains('://')) return urlOrPath;
    final uri = Uri.tryParse(urlOrPath);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    // .../storage/v1/object[/public|/sign]/documents/<path...>
    final bucketIdx = segments.indexOf('documents');
    if (bucketIdx < 0 || bucketIdx + 1 >= segments.length) return null;
    return segments.sublist(bucketIdx + 1).join('/');
  }

  Future<String> uploadBoatPhoto({
    required String userId,
    required String boatId,
    required File file,
  }) async {
    uploadProgress.value = 0.0;
    final compressed = await _compressImage(file);
    uploadProgress.value = 0.5;
    final path = '$userId/$boatId/photo.jpg';

    await supabaseClient.storage.from('boats').uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    uploadProgress.value = 1.0;
    final url = supabaseClient.storage.from('boats').getPublicUrl(path);
    uploadProgress.value = null;
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> uploadDocumentScan({
    required String userId,
    required String documentId,
    required File file,
  }) async {
    uploadProgress.value = 0.0;
    final ext = file.path.contains('.')
        ? '.${file.path.split('.').last}'.toLowerCase()
        : '';
    final isPdf = ext == '.pdf';
    final String path;
    final String contentType;

    if (isPdf) {
      path = '$userId/$documentId/scan.pdf';
      contentType = 'application/pdf';
      uploadProgress.value = 0.5;
      await supabaseClient.storage.from('documents').upload(
            path,
            file,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
    } else {
      path = '$userId/$documentId/scan.jpg';
      contentType = 'image/jpeg';
      final compressed = await _compressImage(file);
      uploadProgress.value = 0.5;
      await supabaseClient.storage.from('documents').uploadBinary(
            path,
            compressed,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
    }

    uploadProgress.value = 1.0;
    final url = supabaseClient.storage.from('documents').getPublicUrl(path);
    uploadProgress.value = null;
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Uploads an invoice/receipt (image or PDF) for a maintenance/expense entry.
  Future<String> uploadInvoice({
    required String userId,
    required File file,
  }) async {
    uploadProgress.value = 0.0;
    final ext = file.path.contains('.')
        ? '.${file.path.split('.').last}'.toLowerCase()
        : '';
    final isPdf = ext == '.pdf';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final String path;
    if (isPdf) {
      path = '$userId/invoices/$stamp.pdf';
      uploadProgress.value = 0.5;
      await supabaseClient.storage.from('documents').upload(
            path,
            file,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
    } else {
      path = '$userId/invoices/$stamp.jpg';
      final compressed = await _compressImage(file);
      uploadProgress.value = 0.5;
      await supabaseClient.storage.from('documents').uploadBinary(
            path,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    }
    uploadProgress.value = 1.0;
    final url = supabaseClient.storage.from('documents').getPublicUrl(path);
    uploadProgress.value = null;
    return url;
  }

  Future<void> deleteBoatPhoto({
    required String userId,
    required String boatId,
  }) async {
    await supabaseClient.storage
        .from('boats')
        .remove(['$userId/$boatId/photo.jpg']);
  }

  Future<void> deleteDocumentScan({
    required String userId,
    required String documentId,
  }) async {
    final list = await supabaseClient.storage
        .from('documents')
        .list(path: '$userId/$documentId');
    if (list.isNotEmpty) {
      final paths = list.map((f) => '$userId/$documentId/${f.name}').toList();
      await supabaseClient.storage.from('documents').remove(paths);
    }
  }

  Future<Uint8List> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    return compute(_processImage, bytes);
  }

  static Uint8List _processImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    img.Image resized;
    if (image.width > 1200) {
      resized = img.copyResize(image, width: 1200);
    } else {
      resized = image;
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }
}
