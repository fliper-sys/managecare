import 'dart:typed_data';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Receipt utility for sharing and downloading receipts
class ReceiptUtility {
  /// Request file storage permissions
  static Future<bool> requestStoragePermission() async {
    // Note: To comply with Google Play's Photo & Video permission policy,
    // avoid requesting READ_MEDIA_IMAGES / READ_MEDIA_VIDEO on Android
    // when only one-time access or writes are needed. Requesting
    // Permission.photos can map to these permissions on Android 13+.

    if (Platform.isAndroid) {
      // Prefer requesting legacy storage permission for file writes when needed
      // and avoid requesting photo library read permissions.
      final storagePermission = await Permission.storage.request();
      return storagePermission.isGranted;
    } else if (Platform.isIOS) {
      // iOS needs photo library permission for photos access
      final permission = await Permission.photos.request();
      return permission.isGranted;
    }
    return true;
  }

  /// Download receipt as text file
  static Future<bool> downloadReceiptAsText({
    required String receiptText,
    required String fileName,
  }) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        print('Storage permission denied');
        return false;
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        print('Downloads directory not found');
        return false;
      }

      final filePath = '${directory.path}/$fileName.txt';
      final file = File(filePath);

      await file.writeAsString(receiptText);
      print('Receipt saved to: $filePath');
      return true;
    } catch (e) {
      print('Error downloading receipt: $e');
      return false;
    }
  }

  /// Download receipt as PDF (requires pdf package)
  static Future<bool> downloadReceiptAsPDF({
    required Uint8List pdfData,
    required String fileName,
  }) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        print('Storage permission denied');
        return false;
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        print('Downloads directory not found');
        return false;
      }

      final filePath = '${directory.path}/$fileName.pdf';
      final file = File(filePath);

      await file.writeAsBytes(pdfData);
      print('PDF receipt saved to: $filePath');
      return true;
    } catch (e) {
      print('Error downloading PDF: $e');
      return false;
    }
  }

  /// Share receipt as text
  static Future<bool> shareReceiptAsText({
    required String receiptText,
    required String businessName,
  }) async {
    try {
      await Share.share(receiptText, subject: '$businessName Receipt');
      return true; // If no exception, share was successful
    } catch (e) {
      print('Error sharing receipt: $e');
      return false;
    }
  }

  /// Share receipt as image (requires screenshot)
  static Future<bool> shareReceiptAsImage({
    required Uint8List imageData,
    required String businessName,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/receipt.png');
      await file.writeAsBytes(imageData);

      final result = await Share.shareXFiles([XFile(file.path)],
          text: 'Receipt from $businessName', subject: '$businessName Receipt');

      return result.status == ShareResultStatus.success;
    } catch (e) {
      print('Error sharing receipt image: $e');
      return false;
    }
  }

  /// Send receipt via email using EmailService
  /// This should be called from your EmailService implementation
  static String formatReceiptForEmail({
    required String receiptText,
    required String businessName,
    required String customerEmail,
  }) {
    final body = '''
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: monospace; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; }
        .receipt { white-space: pre-wrap; }
        .header { text-align: center; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Receipt from $businessName</h2>
        </div>
        <div class="receipt">
$receiptText
        </div>
    </div>
</body>
</html>
''';
    return body;
  }

  /// Generate receipt file name with timestamp
  static String generateReceiptFileName({
    required String businessName,
    String? orderId,
  }) {
    final timestamp =
        DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-');
    final sanitized = businessName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    if (orderId != null && orderId.isNotEmpty) {
      return 'receipt_${sanitized}_${orderId}_$timestamp';
    }

    return 'receipt_${sanitized}_$timestamp';
  }

  /// Convert receipt to thermal printer format
  static String convertToThermalFormat(String receiptText, int paperWidth) {
    final lines = receiptText.split('\n');
    final charsPerLine = paperWidth == 58 ? 32 : 48;

    final buffer = StringBuffer();
    for (var line in lines) {
      if (line.length > charsPerLine) {
        buffer.writeln(line.substring(0, charsPerLine));
      } else {
        buffer.writeln(line);
      }
    }

    return buffer.toString();
  }

  /// Generate a short human-friendly reference id
  /// Format: first 3 letters of business name (uppercase) + '-' + 6 char alphanumeric (e.g. ABC-4F8J2K)
  static String generateReferenceId(String? businessName) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();

    final nameLetters = (businessName ?? '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');

    final prefix = (nameLetters.length >= 3
            ? nameLetters.substring(0, 3)
            : nameLetters.padRight(3, 'X'))
        .toUpperCase();

    final buffer = StringBuffer();
    for (int i = 0; i < 6; i++) {
      buffer.write(chars[rnd.nextInt(chars.length)]);
    }

    return '$prefix-$buffer';
  }

  /// Check if receipt image is available (for screenshot)
  static bool canCaptureReceiptImage() {
    return true; // Will depend on rendering service availability
  }
}

