import 'dart:convert';
import 'dart:typed_data';

import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:business_manager/core/utils/formatters.dart';
import 'package:http/http.dart' as http;
import 'email_template_service.dart';

/// Web-integrated email service that uses PHP endpoints for receipt and notification emails
/// Handles beautiful CSS-formatted emails with file uploads to web server
class WebEmailReceiptService {
  static const String _baseUrl =
      'https://globalthrivealliance.com/emailtemplate';
  static const String _apiKey = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';
  static const String _uploadBaseUrl =
      'https://globalthrivealliance.com/emailtemplate/uploads';

  /// Send receipt email with beautiful CSS formatting
  /// Uses the email_api.php endpoint with receipt template
  Future<bool> sendReceiptEmail({
    required String recipientEmail,
    required String receiptNumber,
    required String businessName,
    required String customerName,
    required double totalAmount,
    required double subtotal,
    required double tax,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    required String? businessLogo,
    required String? businessContact,
    String? customHeader,
    String? customFooter,
  }) async {
    try {
      // Generate beautiful CSS-formatted HTML email
      final emailHtml = EmailTemplateService.generateReceiptEmailHtml(
        businessName: businessName,
        businessLogo: businessLogo,
        businessContact: businessContact,
        receiptNumber: receiptNumber,
        receiptDate: DateTime.now(),
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        tax: tax,
        total: totalAmount,
        paymentMethod: paymentMethod,
        customHeader: customHeader,
        customFooter: customFooter,
      );

      final data = {
        'receiptNumber': receiptNumber,
        'businessName': businessName,
        'customerName': customerName,
        'totalAmount': formatCurrency(totalAmount),
        'subtotal': formatCurrency(subtotal),
        'tax': formatCurrency(tax),
        'paymentMethod': paymentMethod,
        'itemsJson': jsonEncode(items),
        'businessLogo': businessLogo ?? '',
        'businessContact': businessContact ?? '',
        'currency': '₦',
        'emailHtml': emailHtml, // Pass the beautiful HTML
      };

      final success = await _sendTemplateEmail(
        template: 'receipt',
        recipient: recipientEmail,
        subject: 'Your Receipt #$receiptNumber from $businessName',
        data: data,
      );

      return success;
    } catch (e) {
      print('Error sending receipt email: $e');
      return false;
    }
  }

  /// Send sales notification email to business owner
  /// Notifies owner of new sale with customer details
  Future<bool> sendSalesNotification({
    required String ownerEmail,
    required String businessName,
    required String customerName,
    required String customerEmail,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String receiptNumber,
  }) async {
    try {
      // Generate beautiful CSS-formatted notification email
      final emailHtml = EmailTemplateService.generateSalesNotificationHtml(
        businessName: businessName,
        customerName: customerName,
        customerEmail: customerEmail,
        totalAmount: totalAmount,
        items: items,
        paymentMethod: paymentMethod,
        receiptNumber: receiptNumber,
        saleTime: DateTime.now(),
      );

      final data = {
        'businessName': businessName,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'totalAmount': totalAmount.toStringAsFixed(2),
        'itemsJson': jsonEncode(items),
        'paymentMethod': paymentMethod,
        'receiptNumber': receiptNumber,
        'saleTime': DateTime.now().toIso8601String(),
        'emailHtml': emailHtml, // Pass the beautiful HTML
      };

      final success = await _sendTemplateEmail(
        template: 'sales-notification',
        recipient: ownerEmail,
        subject:
            'New Sale: ${formatCurrency(totalAmount)} from $customerName',
        data: data,
      );

      return success;
    } catch (e) {
      print('Error sending sales notification: $e');
      return false;
    }
  }

  /// Send payment reminder email
  Future<bool> sendPaymentReminder({
    required String recipientEmail,
    required String businessName,
    required String customerName,
    required double amountDue,
    required String dueDate,
    String? invoiceNumber,
  }) async {
    try {
      // Parse due date for formatting
      DateTime parsedDueDate;
      try {
        parsedDueDate = parseTimestamp(dueDate);
      } catch (e) {
        parsedDueDate = DateTime.now().add(const Duration(days: 7));
      }

      // Generate beautiful CSS-formatted reminder email
      final emailHtml = EmailTemplateService.generatePaymentReminderHtml(
        businessName: businessName,
        customerName: customerName,
        amount: amountDue,
        dueDate: parsedDueDate,
        invoiceNumber:
            invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
      );

      final data = {
        'businessName': businessName,
        'customerName': customerName,
        'amountDue': amountDue.toStringAsFixed(2),
        'dueDate': dueDate,
        'emailHtml': emailHtml, // Pass the beautiful HTML
      };

      return await _sendTemplateEmail(
        template: 'payment-reminder',
        recipient: recipientEmail,
        subject: 'Payment Reminder from $businessName',
        data: data,
      );
    } catch (e) {
      print('Error sending payment reminder: $e');
      return false;
    }
  }

  /// Send order confirmation email
  Future<bool> sendOrderConfirmation({
    required String recipientEmail,
    required String businessName,
    required String customerName,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    try {
      final data = {
        'businessName': businessName,
        'customerName': customerName,
        'orderId': orderId,
        'itemsJson': jsonEncode(items),
        'totalAmount': totalAmount.toStringAsFixed(2),
      };

      return await _sendTemplateEmail(
        template: 'order',
        recipient: recipientEmail,
        subject: 'Order Confirmation #$orderId from $businessName',
        data: data,
      );
    } catch (e) {
      print('Error sending order confirmation: $e');
      return false;
    }
  }

  /// Internal method to send template emails via PHP endpoint
  Future<bool> _sendTemplateEmail({
    required String template,
    required String recipient,
    required String subject,
    required Map<String, String> data,
    List<dynamic>? attachments,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/email_api.php');
      final request = http.MultipartRequest('POST', uri);

      request.fields['api_key'] = _apiKey;
      request.fields['template'] = template;
      request.fields['recipient'] = recipient;
      request.fields['subject'] = subject;
      request.fields['data'] = jsonEncode(data);

      // Add attachments if provided
      if (attachments != null && attachments.isNotEmpty) {
        for (final file in attachments) {
          if (await file.exists()) {
            try {
              final multipart = await http.MultipartFile.fromPath(
                'attachments[]',
                file.path,
              );
              request.files.add(multipart);
            } catch (e) {
              print('Error adding attachment: $e');
            }
          }
        }
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Email send request timed out');
        },
      );

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return body['success'] == true;
        } catch (e) {
          print('Error parsing email response: $e');
          return response.statusCode == 200;
        }
      }

      print('Email API returned status: ${response.statusCode}');
      print('Response: ${response.body}');
      return false;
    } catch (e) {
      print('Error in _sendTemplateEmail: $e');
      return false;
    }
  }

  /// Upload PDF receipt or image to web server
  /// Returns the public URL accessible via cached network image
  /// Upload a file or bytes to the web server. Accepts either a [Uint8List]
  /// (for web) or a File-like object with a `path` property (for native).
  Future<String?> uploadFileToWebServer(
    dynamic fileOrBytes, {
    String fileType = 'receipt', // 'receipt', 'invoice', 'image', etc.
    String? filename,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload.php');
      final request = http.MultipartRequest('POST', uri);

      request.fields['api_key'] = _apiKey;
      request.fields['file_type'] = fileType;

      // Determine field name based on file type
      final fieldName = _getUploadFieldName(fileType);

      if (fileOrBytes is Uint8List) {
        // Use bytes (web)
        final name = filename ?? 'upload_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final multipart = http.MultipartFile.fromBytes(fieldName, fileOrBytes, filename: name);
        request.files.add(multipart);
      } else {
        // Assume a File-like object with a path property
        final path = (fileOrBytes?.path as String?);
        if (path == null) return null;
        final multipart = await http.MultipartFile.fromPath(fieldName, path);
        request.files.add(multipart);
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('File upload request timed out');
        },
      );

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          if (body['success'] == true && body['url'] != null) {
            final uploadedUrl = body['url'] as String;
            print('File uploaded successfully: $uploadedUrl');
            return uploadedUrl;
          }
        } catch (e) {
          print('Error parsing upload response: $e');
        }
      }

      print('Upload API returned status: ${response.statusCode}');
      print('Response: ${response.body}');
      return null;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  /// Upload multiple files and return URLs
  Future<List<String>> uploadMultipleFiles(
    List<dynamic> files, {
    String fileType = 'document',
  }) async {
    final urls = <String>[];

    for (final file in files) {
      final url = await uploadFileToWebServer(file, fileType: fileType);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Get the appropriate field name for upload based on file type
  String _getUploadFieldName(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return 'image';
      case 'receipt':
      case 'pdf':
        return 'pdf';
      case 'invoice':
        return 'invoice';
      default:
        return 'document';
    }
  }

  /// Delete uploaded file from web server
  Future<bool> deleteUploadedFile(String fileUrl) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload.php');
      final request = http.MultipartRequest('DELETE', uri);

      request.fields['api_key'] = _apiKey;
      request.fields['file_url'] = fileUrl;

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Get cached network image URL for uploaded files
  /// Use this directly with CachedNetworkImage widget
  String getCachedImageUrl(String uploadedUrl) {
    // Ensure the URL points to the web server uploads directory
    if (!uploadedUrl.startsWith('http')) {
      return '$_uploadBaseUrl/$uploadedUrl';
    }
    return uploadedUrl;
  }
}

/// Exception for timeout errors
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

