import 'dart:io';

import 'local_business_storage.dart';
import 'minio_storage_service.dart';

/// Shared file uploader for business-scoped app storage.
class FileUploadService {
  String? lastError;

  Future<String?> uploadFile(File file, {int retries = 2}) async {
    if (!await file.exists()) {
      lastError = 'File not found: ${file.path}';
      return null;
    }
    return uploadBytes(
      await file.readAsBytes(),
      file.path.split('/').last,
      retries: retries,
    );
  }

  Future<String?> uploadBytes(List<int> bytes, String filename,
      {int retries = 2}) async {
    return _upload(bytes, filename, retries: retries);
  }

  Future<String?> uploadBytesWithProgress(List<int> bytes, String filename,
      {required void Function(int sent, int total) onProgress,
      int retries = 2}) async {
    return _upload(
      bytes,
      filename,
      onProgress: onProgress,
      retries: retries,
    );
  }

  Future<String?> _upload(
    List<int> bytes,
    String filename, {
    void Function(int sent, int total)? onProgress,
    required int retries,
  }) async {
    lastError = null;
    if (bytes.isEmpty) {
      lastError = 'No bytes to upload';
      return null;
    }

    final businessId =
        (await LocalBusinessStorage.create()).getCurrentBusinessId();
    if (businessId == null || businessId.isEmpty) {
      lastError = 'No current business selected for upload';
      return null;
    }

    final minio = MinioStorageService();
    final uploadedUrl = await minio.uploadBytes(
      bytes: bytes,
      filename: filename,
      businessId: businessId,
      folder: 'uploads',
      onProgress: onProgress,
      retries: retries,
    );
    if (uploadedUrl == null) {
      lastError = minio.lastError ?? 'Upload failed';
    }
    return uploadedUrl;
  }
}
