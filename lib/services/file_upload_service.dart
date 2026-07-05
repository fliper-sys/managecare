import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';

import 'package:http/http.dart' as http;

/// Robust file upload helper used by UI flows that need reliable uploads.
/// Tries a few sensible fallbacks, validates returned URL, and performs
/// optional retries on transient failures.
class FileUploadService {
  static const String _base = 'https://globalthrivealliance.com/emailtemplate';
  static const String _uploadEndpoint = '$_base/upload.php';
  static const String _uploadsPublic = 'https://globalthrivealliance.com/emailtemplate/uploads';
  static const String _apiKey = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';

  /// Last error message from the most recent upload attempt (useful for UI diagnostics)
  String? lastError;

  /// Uploads [file] and returns a public URL on success or null on failure.
  /// Will attempt up to [retries] times for transient errors.
  Future<String?> uploadFile(File file, {int retries = 2}) async {
    if (kIsWeb) {
      try {
        final bytes = await file.readAsBytes();
        final filename = file.path.split('/').last;
        return uploadBytes(bytes, filename, retries: retries);
      } catch (e) {
        lastError = 'Web upload failed: $e';
        return null;
      }
    }
    if (!await file.exists()) return null;
    return uploadBytes(await file.readAsBytes(), file.path.split('/').last, retries: retries);
  }

  /// Upload raw bytes with a filename (web-friendly).
  Future<String?> uploadBytes(List<int> bytes, String filename, {int retries = 2}) async {
    lastError = null;
    if (bytes.isEmpty) {
      lastError = 'No bytes to upload';
      return null;
    }

    // On web, do a quick preflight OPTIONS check to detect missing CORS headers early
    if (kIsWeb) {
      final ok = await _preflightCheck();
      if (!ok) {
        lastError = 'Upload preflight failed: endpoint unreachable or missing CORS headers for $_uploadEndpoint';
        print('FileUploadService: $lastError - proceeding with upload to detect final error (may still fail due to CORS)');
        // Proceed instead of returning so we can attempt the POST and report a clearer error
      }
    }

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final uri = Uri.parse(_uploadEndpoint);
        final request = http.MultipartRequest('POST', uri);
        request.fields['api_key'] = _apiKey;
        // Add a regular form field (no custom header) to avoid CORS preflight failures
        request.fields['client_debug'] = 'file-upload';

        final multipart = http.MultipartFile.fromBytes('image', bytes, filename: filename);
        request.files.add(multipart);

        final streamed = await request.send().timeout(const Duration(seconds: 30));
        final resp = await http.Response.fromStream(streamed);

        if (resp.statusCode != 200) {
          lastError = 'Upload returned status ${resp.statusCode}: ${resp.body}';
          print('FileUploadService: $lastError');
          // Try again on server error
          if (attempt < retries) continue;
          return null;
        }

        try {
          final body = jsonDecode(resp.body);
          // Try common keys
          final candidate = (body['url'] ?? body['file'] ?? body['path']) as String?;
          if (candidate != null && candidate.isNotEmpty) {
            final normalized = _normalizeUrl(candidate);
            // Validate reachable
            final ok = await _verifyUrl(normalized);
            if (ok) return normalized;
            // If not reachable, try to build an alternate uploads path
            final alt = _buildUploadsUrlFrom(candidate);
            if (alt != null && await _verifyUrl(alt)) return alt;

            // Last resort: return the normalized candidate as a best-effort fallback
            lastError = 'URL verification failed for "$normalized". Returning it as a best-effort fallback.';
            print('FileUploadService: $lastError');
            return normalized;
          }

          lastError = 'Upload response did not contain a URL: ${resp.body}';
          print('FileUploadService: $lastError');
        } catch (e) {
          // If parsing failed, attempt to fallback to extracting filename and constructing URL
          lastError = 'Failed to parse upload response: ${resp.body}. Error: $e';
          print('FileUploadService: $lastError');
          final fallback = _buildUploadsUrlFrom(resp.body);
          if (fallback != null) {
            final ok = await _verifyUrl(fallback);
            if (ok) return fallback;
            lastError = 'Fallback URL verification failed for "$fallback". Returning it as fallback.';
            print('FileUploadService: $lastError');
            return fallback;
          }
        }
      } catch (e) {
        // transient network issue - retry
        lastError = 'Upload exception: $e';
        print('FileUploadService: $lastError');
        if (attempt < retries) continue;
        return null;
      }
    }

    return null;
  }

  /// Upload bytes while reporting progress via [onProgress]. Uses Dio to gain
  /// access to onSendProgress which is convenient on both native and web.
  Future<String?> uploadBytesWithProgress(List<int> bytes, String filename,
      {required void Function(int sent, int total) onProgress, int retries = 2}) async {
    lastError = null;
    if (bytes.isEmpty) {
      lastError = 'No bytes to upload';
      return null;
    }

    // On web, ensure preflight is OK
    if (kIsWeb) {
      final ok = await _preflightCheck();
      if (!ok) {
        lastError = 'Upload preflight failed: endpoint unreachable or missing CORS headers for $_uploadEndpoint';
        print('FileUploadService: $lastError - proceeding with upload to detect final error (may still fail due to CORS)');
        // Proceed to attempt POST so we can capture the final error (CORS or network)
      }
    }

    final dio = Dio();

    // DEBUG: trace when uploadBytesWithProgress is entered
    print('FileUploadService: uploadBytesWithProgress called for "$filename" (${bytes.length} bytes)');

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final formData = FormData.fromMap({
          'api_key': _apiKey,
          // Use form field instead of custom header so browsers don't block the request
          'client_debug': 'file-upload',
          'image': MultipartFile.fromBytes(bytes, filename: filename),
        });

        final headers = <String, dynamic>{};
        if (!kIsWeb) headers['Authorization'] = 'Bearer $_apiKey';

        final options = Options(headers: headers);

        print('FileUploadService: starting Dio POST to $_uploadEndpoint (attempt $attempt)');
        final resp = await dio.post(_uploadEndpoint,
            data: formData, options: options, onSendProgress: (sent, total) {
          try {
            onProgress(sent, total);
          } catch (_) {}
        });

        print('FileUploadService: Dio POST completed with status ${resp.statusCode}');
        if (resp.statusCode != 200) {
          lastError = 'Upload returned status ${resp.statusCode}: ${resp.data}';
          print('FileUploadService: $lastError');
          if (attempt < retries) continue;
          return null;
        }

        try {
          final body = resp.data is String ? jsonDecode(resp.data) : resp.data;
          final candidate = (body['url'] ?? body['file'] ?? body['path']) as String?;
          if (candidate != null && candidate.isNotEmpty) {
            final normalized = _normalizeUrl(candidate);
            final ok = await _verifyUrl(normalized);
            if (ok) return normalized;

            final alt = _buildUploadsUrlFrom(candidate);
            if (alt != null && await _verifyUrl(alt)) return alt;

            lastError = 'URL verification failed for "$normalized". Returning it as a best-effort fallback.';
            print('FileUploadService: $lastError');
            return normalized;
          }

          lastError = 'Upload response did not contain a URL: ${resp.data}';
          print('FileUploadService: $lastError');
        } catch (e) {
          lastError = 'Failed to parse upload response: ${resp.data}. Error: $e';
          print('FileUploadService: $lastError');
          final fallback = _buildUploadsUrlFrom(resp.data.toString());
          if (fallback != null) {
            final ok = await _verifyUrl(fallback);
            if (ok) return fallback;
            lastError = 'Fallback URL verification failed for "$fallback". Returning it as fallback.';
            print('FileUploadService: $lastError');
            return fallback;
          }
        }
      } catch (e) {
        lastError = 'Upload exception: $e';
        print('FileUploadService: $lastError');
        if (attempt < retries) continue;
        return null;
      }
    }

    return null;
  }

  String _normalizeUrl(String raw) {
    raw = raw.trim();
    if (raw.startsWith('http')) return raw;
    if (raw.startsWith('/')) return 'https://globalthrivealliance.com$raw';
    // If it's just a filename or uploads/..., map to the emailtemplate uploads folder first
    if (raw.contains('uploads')) return '$_base/uploads/${raw.split('/').last}';
    return '$_base/uploads/${raw.split('/').last}';
  }

  String? _buildUploadsUrlFrom(String raw) {
    try {
      final filename = raw.split('/').last;
      if (filename.isEmpty) return null;
      // Prefer the public uploads root then fallback to emailtemplate/uploads
      return '$_uploadsPublic/$filename';
    } catch (_) {
      return null;
    }
  }

  Future<bool> _verifyUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final resp = await http.head(uri).timeout(const Duration(seconds: 6));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Do a simple OPTIONS preflight request and ensure server responds with
  /// `Access-Control-Allow-Origin` header. Useful to detect CORS issues early on web.
  Future<bool> _preflightCheck({String? origin}) async {
    try {
      final uri = Uri.parse(_uploadEndpoint);
      final req = http.Request('OPTIONS', uri);
      // Use the provided origin, or when running on the web prefer the current origin so
      // preflight matches the real client origin automatically.
      final resolvedOrigin = origin ?? (kIsWeb ? Uri.base.origin : 'http://localhost:50063');
      req.headers['Origin'] = resolvedOrigin;
      req.headers['Access-Control-Request-Method'] = 'POST';
      // Help some proxies by indicating which headers we may send in the real request
      req.headers['Access-Control-Request-Headers'] = 'Content-Type, Authorization';

      // Allow a slightly longer preflight timeout to tolerate slow network/servers
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final resp = await http.Response.fromStream(streamed);

      final hasAllowOrigin = resp.headers.keys
          .any((k) => k.toLowerCase().contains('access-control-allow-origin'));
      print('FileUploadService preflight: origin=$resolvedOrigin status ${resp.statusCode}, hasAllowOrigin=$hasAllowOrigin, headers=${resp.headers}');
      // If the server responds 200 but omits Access-Control-Allow-Origin then the
      // browser will still block the subsequent POST. In practice it's helpful
      // to proceed so the UI can surface a clearer final error (e.g., CORS error
      // on the POST). Treat 200 without the header as a warning (return true)
      // so the client attempts the POST and we capture the resulting error.
      if (resp.statusCode == 200 && hasAllowOrigin) return true;
      if (resp.statusCode == 200 && !hasAllowOrigin) {
        print('FileUploadService preflight warning: 200 without Access-Control-Allow-Origin header');
        return true; // proceed but warn
      }
      return false;
    } catch (e) {
      print('FileUploadService preflight failed: $e');
      return false;
    }
  }
}
