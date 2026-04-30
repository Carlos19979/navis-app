import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:navis_mobile/core/network/supabase_client.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final uploadProgress = ValueNotifier<double?>(null);

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
