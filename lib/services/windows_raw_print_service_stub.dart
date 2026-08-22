// Stub for web platform where FFI is not available
import 'dart:async';

class WindowsRawPrintService {
  static Future<String?> defaultPrinterName() async {
    return null;
  }

  static Future<void> printPlainText({
    required String text,
    String? printerName,
    String jobName = 'Manage Care Receipt',
    bool cutPaper = true,
    int charsPerLine = 30,
  }) async {
    // No-op on web
  }
}
