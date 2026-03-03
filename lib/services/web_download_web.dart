import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Trigger a browser download of bytes with the given filename and mime type.
/// Only available on web platform.
void downloadBytes(Uint8List bytes, String filename, String mimeType) {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    throw UnsupportedError('downloadBytes is only available on web platform: $e');
  }
}

/// Trigger browser print dialog for PDF bytes
/// Efficiently opens the browser's print dialog for PDF data
Future<void> printPdfBytes(Uint8List pdfBytes, String jobName) async {
  try {
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final iframe = html.IFrameElement()
      ..src = url
      ..style.display = 'none';
    
    html.document.body?.append(iframe);
    
    // Wait for iframe to load, then trigger print
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Use JavaScript to print the iframe content
    try {
      iframe.contentWindow?.postMessage('print', '*');
      // Fallback: try accessing print directly via dynamic cast
      final jsObject = iframe.contentWindow as dynamic;
      jsObject.print();
    } catch (_) {
      // If direct print fails, open in new window instead
      html.window.open(url, '_blank');
    }
    
    // Clean up after print dialog closes (best effort)
    await Future.delayed(const Duration(seconds: 2));
    iframe.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    throw UnsupportedError('printPdfBytes is only available on web platform: $e');
  }
}
