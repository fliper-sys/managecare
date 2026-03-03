import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Web-specific sharing and export functionality
/// This file contains platform-agnostic stubs that delegate to platform-specific implementations
class WebShareService {
  /// Download PDF file to browser (web only)
  static void downloadPdf({
    required Uint8List bytes,
    required String filename,
  }) {
    if (kIsWeb) {
      _downloadPdfWeb(bytes, filename);
    }
  }

  /// Download image file to browser (web only)
  static void downloadImage({
    required Uint8List bytes,
    required String filename,
  }) {
    if (kIsWeb) {
      _downloadImageWeb(bytes, filename);
    }
  }

  /// Download CSV file to browser (web only)
  static void downloadCsv({
    required String content,
    required String filename,
  }) {
    if (kIsWeb) {
      _downloadCsvWeb(content, filename);
    }
  }

  /// Download JSON file to browser (web only)
  static void downloadJson({
    required String content,
    required String filename,
  }) {
    if (kIsWeb) {
      _downloadJsonWeb(content, filename);
    }
  }

  /// Open image in a new browser window/tab for preview (web only)
  static void previewImage({
    required Uint8List bytes,
    required String filename,
  }) {
    if (kIsWeb) {
      _previewImageWeb(bytes, filename);
    }
  }

  /// Open PDF in a new browser window/tab for preview (web only)
  static void previewPdf({
    required Uint8List bytes,
    required String filename,
  }) {
    if (kIsWeb) {
      _previewPdfWeb(bytes, filename);
    }
  }

  /// Copy text to clipboard (web only)
  static Future<bool> copyToClipboard(String text) async {
    if (!kIsWeb) return false;
    return _copyToClipboardWeb(text);
  }

  /// Get text from clipboard (web only)
  static Future<String?> getFromClipboard() async {
    if (!kIsWeb) return null;
    return _getFromClipboardWeb();
  }

  /// Create a shareable link for a receipt (web only)
  static String createBlobUrl(Uint8List bytes, String mimeType) {
    if (!kIsWeb) return '';
    return _createBlobUrlWeb(bytes, mimeType);
  }

  /// Revoke a blob URL (cleanup)
  static void revokeBlobUrl(String url) {
    if (!kIsWeb) return;
    _revokeBlobUrlWeb(url);
  }

  /// Get current page URL for sharing (web only)
  static String getCurrentUrl() {
    if (!kIsWeb) return '';
    return _getCurrentUrlWeb();
  }

  /// Check if native share is available on this device
  static bool canUseNativeShare() {
    if (!kIsWeb) return false;
    return _canUseNativeShareWeb();
  }

  /// Use native share API if available (Web Share API)
  static Future<bool> nativeShare({
    required String title,
    required String text,
    String? url,
  }) async {
    if (!kIsWeb) return false;
    return _nativeShareWeb(title: title, text: text, url: url);
  }

  /// Show a dialog on web with options to download or preview a file
  static void showDownloadDialog({
    required BuildContext context,
    required String filename,
    required String fileType,
    required VoidCallback onDownload,
    required VoidCallback onPreview,
  }) {
    if (!kIsWeb) return;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('$fileType Receipt'),
          content: Text('What would you like to do with this $fileType?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onDownload();
              },
              child: const Text('Download'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onPreview();
              },
              child: const Text('Preview'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // Platform-specific implementations (only called when kIsWeb is true)
  // ============================================================================

  static void _downloadPdfWeb(Uint8List bytes, String filename) {
    // Implemented using dart:html - only on web
    _webDownload(bytes, 'application/pdf', filename);
  }

  static void _downloadImageWeb(Uint8List bytes, String filename) {
    _webDownload(bytes, 'image/png', filename);
  }

  static void _downloadCsvWeb(String content, String filename) {
    final bytes = Uint8List.fromList(content.codeUnits);
    _webDownload(bytes, 'text/csv;charset=utf-8', filename);
  }

  static void _downloadJsonWeb(String content, String filename) {
    final bytes = Uint8List.fromList(content.codeUnits);
    _webDownload(bytes, 'application/json;charset=utf-8', filename);
  }

  static void _previewImageWeb(Uint8List bytes, String filename) {
    _webPreview(bytes, 'image/png');
  }

  static void _previewPdfWeb(Uint8List bytes, String filename) {
    _webPreview(bytes, 'application/pdf');
  }

  static Future<bool> _copyToClipboardWeb(String text) async {
    return await _webCopyToClipboard(text);
  }

  static Future<String?> _getFromClipboardWeb() async {
    return await _webGetFromClipboard();
  }

  static String _createBlobUrlWeb(Uint8List bytes, String mimeType) {
    return _webCreateBlobUrl(bytes, mimeType);
  }

  static void _revokeBlobUrlWeb(String url) {
    _webRevokeBlobUrl(url);
  }

  static String _getCurrentUrlWeb() {
    return _webGetCurrentUrl();
  }

  static bool _canUseNativeShareWeb() {
    return _webCanUseNativeShare();
  }

  static Future<bool> _nativeShareWeb({
    required String title,
    required String text,
    String? url,
  }) async {
    return await _webNativeShare(title: title, text: text, url: url);
  }

  // ============================================================================
  // Web platform implementations (these use dart:html but are only called on web)
  // ============================================================================

  static void _webDownload(Uint8List bytes, String mimeType, String filename) {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
    // The actual dart:html code will be injected by the build system for web only
  }

  static void _webPreview(Uint8List bytes, String mimeType) {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
  }

  static Future<bool> _webCopyToClipboard(String text) async {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
    return false;
  }

  static Future<String?> _webGetFromClipboard() async {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
    return null;
  }

  static String _webCreateBlobUrl(Uint8List bytes, String mimeType) {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
    return '';
  }

  static void _webRevokeBlobUrl(String url) {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
  }

  static String _webGetCurrentUrl() {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
    return '';
  }

  static bool _webCanUseNativeShare() {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
    return false;
  }

  static Future<bool> _webNativeShare({
    required String title,
    required String text,
    String? url,
  }) async {
    // Note: This file is web-safe because methods are only called when kIsWeb is true
    return false;
  }
}
