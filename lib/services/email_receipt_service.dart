import 'dart:io';
import 'file_upload_service.dart';
import 'email_service.dart';


class EmailReceiptService {

  /// Send receipt via email using the web email endpoints
  Future<bool> sendReceiptEmail({
    required String recipientEmail,
    required String receiptNumber,
    required String businessName,
    required File pdfFile,
    required double totalAmount,
    required String customerName,
  }) async {
    try {
      // Upload PDF to web server and obtain a public URL
      final uploader = FileUploadService();
      final downloadUrl = await uploader.uploadFile(pdfFile);

      if (downloadUrl == null) {
        print('Error sending receipt email: server upload failed');
        return false;
      }

      // Use the web API to send the email using the 'receipt' template
      final emailService = EmailService();
      final data = {
        'businessName': businessName,
        'receiptNumber': receiptNumber,
        'customerName': customerName,
        'receiptUrl': downloadUrl,
        'total': totalAmount.toStringAsFixed(2),
      };

      final ok = await emailService.sendTemplateEmail('receipt', recipientEmail, data, subject: 'Receipt #$receiptNumber');

      if (!ok) {
        print('Web email API failed to send receipt for $recipientEmail');
      }

      return ok;
    } catch (e) {
      print('Error sending receipt email: $e');
      return false;
    }
  }

  /// Send receipt email with multiple recipients
  Future<bool> sendReceiptToMultiple({
    required List<String> recipientEmails,
    required String receiptNumber,
    required String businessName,
    required File pdfFile,
    required double totalAmount,
    required String customerName,
  }) async {
    try {
      final uploader = FileUploadService();
      final downloadUrl = await uploader.uploadFile(pdfFile);

      if (downloadUrl == null) {
        print('Error sending receipt emails: server upload failed');
        return false;
      }

      final emailService = EmailService();
      final data = {
        'businessName': businessName,
        'receiptNumber': receiptNumber,
        'customerName': customerName,
        'receiptUrl': downloadUrl,
        'total': totalAmount.toStringAsFixed(2),
      };

      // Send to each recipient sequentially (could be parallelized if needed)
      for (final r in recipientEmails) {
        final ok = await emailService.sendTemplateEmail('receipt', r, data, subject: 'Receipt #$receiptNumber');
        if (!ok) {
          print('Failed to send receipt to $r');
        }
      }

      return true;
    } catch (e) {
      print('Error sending receipt emails: $e');
      return false;
    }
  }

  /// Delete receipt from storage
  Future<bool> deleteReceipt(String receiptNumber) async {
    // Deleting files requires a server-side API; not implemented yet.
    print('deleteReceipt: server-side delete not implemented for $receiptNumber');
    return false;
  }
}

