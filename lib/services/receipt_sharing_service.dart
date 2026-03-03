import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'snackbar_service.dart';

class ReceiptSharingService {
  /// Share receipt PDF via native share dialog
  static Future<void> shareReceiptPdf({
    required File pdfFile,
    required String receiptNumber,
    required BuildContext context,
  }) async {
    try {
      final subject = 'Receipt #$receiptNumber';
      const text = 'Please find attached your receipt';

      await Share.shareXFiles([XFile(pdfFile.path)],
          text: text, subject: subject);
    } catch (e) {
      // Use global SnackBarService to avoid showing SnackBar with a context that
      // might be deactivated while the animation runs.
      SnackBarService.showSnackBar(message: 'Error sharing receipt: $e', context: context);
    }
  }

  /// Share receipt via WhatsApp
  static Future<void> shareViaWhatsApp({
    required File pdfFile,
    required String receiptNumber,
    required String customerName,
    required BuildContext context,
  }) async {
    try {
      final message = 'Hi $customerName, here is your receipt #$receiptNumber';

      await Share.shareXFiles([XFile(pdfFile.path)],
          text: message, subject: 'Receipt #$receiptNumber');
    } catch (e) {
      SnackBarService.showSnackBar(message: 'Error sharing via WhatsApp: $e', context: context);
    }
  }

  /// Share receipt via email (opens default email client)
  static Future<void> shareViaEmail({
    required File pdfFile,
    required String receiptNumber,
    required String customerEmail,
    required String businessName,
    required BuildContext context,
  }) async {
    try {
      final subject = 'Your Receipt from $businessName - #$receiptNumber';
      const body = 'Dear Customer,\n\n'
          'Please find attached your receipt.\n\n'
          'Thank you for your business!';

      await Share.shareXFiles([XFile(pdfFile.path)],
          text: body, subject: subject);
    } catch (e) {
      SnackBarService.showSnackBar(message: 'Error sharing via email: $e', context: context);
    }
  }

  /// Get shareable receipt file path
  static Future<String> getReceiptPath(String receiptNumber) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/receipt_$receiptNumber.pdf';
  }

  /// Create shareable receipt file
  static Future<File?> createShareableReceipt({
    required File sourceFile,
    required String receiptNumber,
  }) async {
    try {
      final appDir = await getTemporaryDirectory();
      final fileName = 'receipt_$receiptNumber.pdf';
      final file = File('${appDir.path}/$fileName');

      await file.writeAsBytes(await sourceFile.readAsBytes());
      return file;
    } catch (e) {
      print('Error creating shareable receipt: $e');
      return null;
    }
  }
}

