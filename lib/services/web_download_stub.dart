import 'dart:typed_data';

/// Stub implementation for non-web platforms. The real implementation
/// is provided by `web_download_web.dart` when compiled for web.
void downloadBytes(Uint8List bytes, String filename, String mimeType) {
  throw UnsupportedError('Web downloads are not supported on this platform.');
}

/// Stub for printPdfBytes - non-web platforms
Future<void> printPdfBytes(Uint8List pdfBytes, String jobName) {
  throw UnsupportedError('Web printing is not supported on this platform.');
}
