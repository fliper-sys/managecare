import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import 'pdf_receipt_generator.dart';
import 'web_email_receipt_service.dart';
import 'admin_notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_and_email_service.dart';
import 'dart:typed_data';
import 'web_download.dart' as web_download;

class CheckoutReceiptHandler {
  static const uuid = Uuid();

  /// Generate receipt and show confirmation dialog with web-integrated email sending
  static Future<void> handleCheckoutReceipt({
    required BuildContext context,
    required String businessName,
    required String businessEmail,
    required String? businessLogo,
    required String? businessContact,
    required String customerName,
    required String? customerEmail,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double total,
    required String paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    required String? customHeader,
    required String? customFooter,
    required String paperWidth,
    required Function(bool success) onComplete,
  }) async {
    try {
      // Generate receipt number
      final receiptNumber = _generateReceiptNumber();


      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Generating receipt...'),
              ],
            ),
          ),
        );
      }

      // Generate PDF receipt (use bytes on web)
      Uint8List? pdfBytes;
      dynamic pdfFile;

      final _customFooter = customFooter;
      final footerWithPowered = (_customFooter?.isNotEmpty == true) ? '$_customFooter\nPowered by Manage Care' : 'Powered by Manage Care';
      const cashierName = 'Staff';

      if (kIsWeb) {
        pdfBytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
          businessName: businessName,
          receiptNumber: receiptNumber,
          receiptDate: DateTime.now(),
          items: items,
          subtotal: subtotal,
          tax: tax,
          total: total,
          paymentMethod: paymentMethod,
          paymentBreakdown: paymentBreakdown,
          customerName: customerName,
          customerEmail: customerEmail,
          customHeader: customHeader,
          customFooter: footerWithPowered,
          paperWidth: paperWidth,
          cashier: cashierName,
          poweredByText: footerWithPowered,
          showQrCode: false,
        );
      } else {
        pdfFile = await PdfReceiptGenerator.generateReceiptPdf(
          businessName: businessName,
          receiptNumber: receiptNumber,
          receiptDate: DateTime.now(),
          items: items,
          subtotal: subtotal,
          tax: tax,
          total: total,
          paymentMethod: paymentMethod,
          paymentBreakdown: paymentBreakdown,
          customerName: customerName,
          customerEmail: customerEmail,
          customHeader: customHeader,
          customFooter: footerWithPowered,
          paperWidth: paperWidth,
          cashier: cashierName,
          poweredByText: footerWithPowered,
          showQrCode: false,
        );
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      // Show receipt confirmation dialog
      if (context.mounted) {
        await showDialog<bool>(
          context: context,
          builder: (ctx) => _buildWebIntegratedReceiptDialog(
            context: ctx,
            receiptNumber: receiptNumber,
            businessName: businessName,
            businessEmail: businessEmail,
            businessLogo: businessLogo,
            businessContact: businessContact,
            customerName: customerName,
            customerEmail: customerEmail,
            total: total,
            subtotal: subtotal,
            tax: tax,
            items: items,
            paymentMethod: paymentMethod,
            paymentBreakdown: paymentBreakdown,
            pdfFile: pdfFile,
            pdfBytes: pdfBytes, onEmailSent: () {  },
          ),
        );
      }
      onComplete(false);
    } catch (e) {
      // Dismiss any loading dialog if still visible
      if (context.mounted) {
        try { Navigator.pop(context); } catch (_) {}
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to generate receipt: $e'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
      onComplete(false);
    }
  }

  /// Build web-integrated receipt dialog with beautiful email formatting
  static Widget _buildWebIntegratedReceiptDialog({
    required BuildContext context,
    required String receiptNumber,
    required String businessName,
    required String businessEmail,
    required String? businessLogo,
    required String? businessContact,
    required String customerName,
    required String? customerEmail,
    required double total,
    required double subtotal,
    required double tax,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    dynamic pdfFile,
    Uint8List? pdfBytes,
    required VoidCallback onEmailSent,
  }) {
    bool isSending = false;
    final webEmailService = WebEmailReceiptService();

    return StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Receipt Generated'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receipt #$receiptNumber',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How would you like to handle this receipt?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                // Send Receipt Email Option
                if (customerEmail != null)
                  GestureDetector(
                    onTap: isSending
                        ? null
                        : () async {
                            setState(() => isSending = true);
                            try {
                              // Send receipt email with CSS formatting
                              final success =
                                  await webEmailService.sendReceiptEmail(
                                recipientEmail: customerEmail,
                                receiptNumber: receiptNumber,
                                businessName: businessName,
                                customerName: customerName,
                                totalAmount: total,
                                subtotal: subtotal,
                                tax: tax,
                                items: items,
                                paymentMethod: paymentMethod,
                                paymentBreakdown: paymentBreakdown,
                                businessLogo: businessLogo,
                                businessContact: businessContact,
                              );

                              if (success) {
                                // Send sales notification to owner
                                final ownerSuccess = await webEmailService.sendSalesNotification(
                                  ownerEmail: businessEmail,
                                  businessName: businessName,
                                  customerName: customerName,
                                  customerEmail: customerEmail,
                                  totalAmount: total,
                                  items: items,
                                  paymentMethod: paymentMethod,
                                  receiptNumber: receiptNumber,
                                );

                                // Try to log the notification event by resolving business id from email
                                try {
                                  final notif = NotificationAndEmailService();
                                  final firestore = FirebaseFirestore.instance;
                                  final query = await firestore
                                      .collection('businesses')
                                      .where('email', isEqualTo: businessEmail)
                                      .limit(1)
                                      .get();
                                  final businessId = query.docs.isNotEmpty
                                      ? query.docs.first.id
                                      : null;
                                  if (businessId != null) {
                                    await notif.logNotificationEvent(
                                      businessId: businessId,
                                      type: 'sale',
                                      channel: 'email',
                                      recipient: businessEmail,
                                      success: ownerSuccess,
                                      orderId: receiptNumber,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('[ReceiptHandler] Notification log failed: $e');
                                }

                                onEmailSent();
                                if (ctx.mounted) {
                                  Navigator.pop(ctx, true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Receipt and notification emails sent!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to send emails'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setState(() => isSending = false);
                              }
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blue[300]!,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_rounded,
                            color: Colors.blue,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Send via Email',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  customerEmail,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Beautiful CSS-formatted email',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSending)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Save / Download Option
                GestureDetector(
                  onTap: () {
                    if (kIsWeb) {
                      if (pdfBytes != null) {
                        web_download.downloadBytes(pdfBytes, PdfReceiptGenerator.getReceiptFilename(receiptNumber), 'application/pdf');
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Receipt downloaded'), backgroundColor: Colors.green),
                        );
                      } else {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('No receipt available to download'), backgroundColor: Colors.red),
                        );
                      }
                      Navigator.pop(ctx, true);
                    } else {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kIsWeb ? 'Download Receipt' : 'Receipt Saved',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                kIsWeb ? 'Downloaded to your browser' : 'Continue with checkout',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx, false),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Generate unique receipt number
  static String _generateReceiptNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = uuid.v4().split('-').first.toUpperCase();
    return '${timestamp.toString().substring(timestamp.toString().length - 6)}$random';
  }

  /// Notify admin of payment
  // ignore: unused_element
  static Future<void> _notifyAdminPayment(
    String businessName,
    String customerName,
    double amount,
    String receiptNumber,
  ) async {
    try {
      final notificationService = AdminNotificationService();
      await notificationService.createPaymentNotification(
        businessName: businessName,
        amount: amount.toStringAsFixed(2),
        tier: 'subscription',
        paymentData: {
          'customerName': customerName,
          'receiptNumber': receiptNumber,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('Error notifying admin: $e');
    }
  }
}

