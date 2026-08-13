import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../core/config/supabase_config.dart';

/// MinIO-backed storage service using the self-hosted Express API upload
/// endpoint at backend.managecare.info/api/upload/:businessId.
///
/// Replaces Firebase Storage by routing all file uploads through the
/// self-hosted backend which forwards to MinIO (port 9000 on the VPS).
class MinioStorageService {
  static final MinioStorageService _instance = MinioStorageService._internal();
  final Dio _http;
  final SupabaseClient _supabase;

  String? lastError;

  factory MinioStorageService() {
    return _instance;
  }

  MinioStorageService._internal()
      : _http = Dio(BaseOptions(
          baseUrl: '${SupabaseConfig.url}/api',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 60),
        )),
        _supabase = Supabase.instance.client;

  String? get _accessToken => _supabase.auth.currentSession?.accessToken;
  Map<String, dynamic> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/json',
      };

  /// Upload a file and return the public URL.
  Future<String?> uploadFile({
    required File file,
    required String businessId,
    String folder = 'uploads',
    void Function(int sent, int total)? onProgress,
    int retries = 2,
  }) async {
    if (!await file.exists()) {
      lastError = 'File not found: ${file.path}';
      return null;
    }
    final bytes = await file.readAsBytes();
    final filename = file.path.split('/').last;
    return uploadBytes(
      bytes: bytes,
      filename: filename,
      businessId: businessId,
      folder: folder,
      onProgress: onProgress,
      retries: retries,
    );
  }

  /// Upload raw bytes and return the public URL.
  Future<String?> uploadBytes({
    required List<int> bytes,
    required String filename,
    required String businessId,
    String folder = 'uploads',
    void Function(int sent, int total)? onProgress,
    int retries = 2,
  }) async {
    lastError = null;
    if (bytes.isEmpty) {
      lastError = 'No bytes to upload';
      return null;
    }

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
          'folder': folder,
        });

        final options = Options(
          headers: _headers,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 60),
        );

        final response = await _http.post(
          '/upload/$businessId',
          data: formData,
          options: options,
          onSendProgress: onProgress,
        );

        if (response.statusCode != 201) {
          lastError = 'Upload returned status ${response.statusCode}';
          if (attempt < retries) continue;
          return null;
        }

        final body = response.data is Map
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data as String) as Map<String, dynamic>;
        final url = body['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }

        lastError = 'Upload response missing URL';
        if (attempt < retries) continue;
        return null;
      } on DioException catch (e) {
        lastError = 'Upload failed (attempt $attempt): ${e.message}';
        if (attempt < retries) continue;
        return null;
      } catch (e) {
        lastError = 'Unexpected upload error: $e';
        if (attempt < retries) continue;
        return null;
      }
    }

    return null;
  }

  /// Get file metadata from MinIO via the API.
  Future<Map<String, dynamic>?> getFileMetadata({
    required String businessId,
    required String filename,
  }) async {
    try {
      final response = await _http.get(
        '/upload/$businessId/$filename',
        options: Options(headers: _headers),
      );
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      lastError = 'Failed to get file metadata: ${e.message}';
      return null;
    }
  }

  /// Delete a file (not yet implemented server-side).
  Future<void> deleteFile(String fileUrl) async {
    throw UnsupportedError(
      'Server-side file deletion is not implemented yet. '
      'File URL: $fileUrl',
    );
  }

  /// Check if a URL is reachable.
  Future<bool> verifyUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await _http.headUri(uri);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Resolve a download URL.
  Future<String> getDownloadUrl(String filePath) async {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    return '${SupabaseConfig.url}/api/upload/$filePath';
  }

  Future<void> initialize() async {}
}
