import 'dart:io';
import 'file_upload_service.dart';

/// Cloud storage service backed by the application's server upload endpoint
class CloudStorageService {
  static final CloudStorageService _instance = CloudStorageService._internal();
  final FileUploadService _uploader = FileUploadService();

  factory CloudStorageService() {
    return _instance;
  }

  CloudStorageService._internal();

  /// Initialize is a no-op for server-backed uploads
  Future<void> initialize() async {
    return;
  }

  /// Upload file to server and return a public URL
  Future<String> uploadFile(
    String filePath,
    String destination,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }

    final url = await _uploader.uploadFile(file);
    if (url == null) throw Exception('Upload failed for $filePath');
    return url;
  }

  /// Upload bytes by writing a temp file and delegating to uploader
  Future<String> uploadBytes(
    List<int> bytes,
    String destination, {
    String contentType = 'application/octet-stream',
  }) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}');
    await file.writeAsBytes(bytes);
    final url = await _uploader.uploadFile(file);
    if (url == null) throw Exception('Upload failed');
    return url;
  }

  /// Delete file from server - requires a server-side API (not implemented)
  Future<void> deleteFile(String fileUrl) async {
    print('deleteFile: server-side delete not implemented for $fileUrl');
    throw UnsupportedError('Server-side delete not implemented');
  }

  /// Listing files is not supported without a server API
  Future<List<String>> listFiles(String folder) async {
    throw UnsupportedError('Listing files is not supported by server uploads');
  }

  /// Get file download URL - if the stored value is a URL return it, otherwise attempt to construct a public URL
  Future<String> getDownloadUrl(String filePath) async {
    if (filePath.startsWith('http')) return filePath;
    final filename = filePath.split('/').last;
    return 'https://globalthrivealliance.com/uploads/$filename';
  }

  /// Metadata retrieval is not supported without a server API
  Future<Map<String, dynamic>> getFileMetadata(String filePath) async {
    throw UnsupportedError('File metadata not supported for server uploads');
  }


}

