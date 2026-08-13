import 'dart:io';
import 'package:flutter/foundation.dart';
import 'minio_storage_service.dart';

/// Cloud storage service backed by MinIO via the self-hosted backend.
///
/// Replaces the old globalthrivealliance.com PHP upload endpoint with the
/// self-hosted MinIO storage on the VPS (port 9000, bucket managecare-files).
///
/// All uploads are routed through the Express API:
///   POST /api/upload/:businessId → MinIO → returns public URL
class CloudStorageService {
  static final CloudStorageService _instance = CloudStorageService._internal();
  final MinioStorageService _minio = MinioStorageService();
  String? _businessId;

  factory CloudStorageService() {
    return _instance;
  }

  CloudStorageService._internal();

  /// Initialize with an optional default businessId.
  /// Call this during app startup after the user/business context is known.
  Future<void> initialize({String? businessId}) async {
    _businessId = businessId;
    await _minio.initialize();
    debugPrint('[CloudStorageService] Initialized (businessId: $businessId)');
    return;
  }

  /// Set the default business ID for subsequent uploads.
  void setBusinessId(String businessId) {
    _businessId = businessId;
  }

  /// Upload a file and return a public URL.
  /// [destination] is the folder path on MinIO (e.g. "receipts", "products").
  /// If [businessId] is not provided, uses the default set during initialization.
  Future<String> uploadFile(
    String filePath,
    String destination, {
    String? businessId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }

    final bizId = businessId ?? _businessId;
    if (bizId == null || bizId.isEmpty) {
      throw Exception('businessId is required for upload. Provide it or call initialize() first.');
    }

    final url = await _minio.uploadFile(
      file: file,
      businessId: bizId,
      folder: destination,
      onProgress: onProgress,
    );

    if (url == null) {
      throw Exception('Upload failed: ${_minio.lastError ?? "Unknown error"}');
    }

    return url;
  }

  /// Upload raw bytes and return a public URL.
  Future<String> uploadBytes(
    List<int> bytes,
    String destination, {
    String? businessId,
    String contentType = 'application/octet-stream',
    void Function(int sent, int total)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('No bytes to upload');
    }

    final bizId = businessId ?? _businessId;
    if (bizId == null || bizId.isEmpty) {
      throw Exception('businessId is required for upload');
    }

    // Generate a filename from the destination path or timestamp
    final filename = destination.contains('/')
        ? destination.split('/').last
        : 'upload_${DateTime.now().millisecondsSinceEpoch}';

    final url = await _minio.uploadBytes(
      bytes: bytes,
      filename: filename,
      businessId: bizId,
      folder: destination.contains('/')
          ? destination.substring(0, destination.lastIndexOf('/'))
          : 'uploads',
      onProgress: onProgress,
    );

    if (url == null) {
      throw Exception('Upload failed: ${_minio.lastError ?? "Unknown error"}');
    }

    return url;
  }

  /// Delete a file from MinIO storage.
  Future<void> deleteFile(String fileUrl) async {
    await _minio.deleteFile(fileUrl);
  }

  /// List files in a folder (not directly supported by MinIO API wrapper yet).
  Future<List<String>> listFiles(String folder) async {
    throw UnsupportedError(
      'Listing files is not supported by the MinIO upload proxy. '
      'Use the backend API directly if needed.',
    );
  }

  /// Get a valid download URL for the given file path.
  /// If already a full URL, returns as-is; otherwise resolves via MinIO.
  Future<String> getDownloadUrl(String filePath) async {
    return _minio.getDownloadUrl(filePath);
  }

  /// Get file metadata from MinIO via the backend API.
  /// [filePath] can be a URL or a filename (relative path).
  /// Optionally provide [businessId] if resolving a relative path.
  Future<Map<String, dynamic>> getFileMetadata(
    String filePath, {
    String? businessId,
  }) async {
    // If it's a full URL, extract the filename
    String filename;
    String? bizId;

    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      final uri = Uri.parse(filePath);
      filename = uri.pathSegments.last;
      // Try to extract businessId from the URL path
      // e.g., /api/upload/{businessId}/{filename}
      final segments = uri.pathSegments;
      if (segments.length >= 3) {
        bizId = segments[segments.length - 2];
      }
    } else {
      filename = filePath.split('/').last;
    }

    bizId = bizId ?? businessId ?? _businessId;
    if (bizId == null) {
      throw Exception('businessId is required to resolve file metadata');
    }

    final metadata = await _minio.getFileMetadata(
      businessId: bizId,
      filename: filename,
    );

    if (metadata == null) {
      throw Exception('File metadata not found for: $filePath');
    }

    return metadata;
  }
}

