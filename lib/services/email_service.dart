import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'file_upload_service.dart';
import 'email_template_service.dart';

/// Simple EmailService to call the server-side email and upload endpoints.
class EmailService {
  // Adjust base URL if needed
  static const String _base = 'https://globalthrivealliance.com/emailtemplate';
  static const String _apiKey = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';

  /// Send a template-based email using `email_api.php` on the server.
  /// [template] should match one of the templates (e.g. 'welcome', 'payment').
  /// [data] is a map of placeholder keys -> values (will be substituted as {{key}}).
  /// [attachments] may include files to upload and attach to the email.
  Future<bool> sendTemplateEmail(
    String template,
    String recipient,
    Map<String, dynamic> data, {
    String? subject,
    List<File>? attachments,
  }) async {
    final uri = Uri.parse('$_base/email_api.php');

    final request = http.MultipartRequest('POST', uri);
    request.fields['api_key'] = _apiKey;
    request.fields['template'] = template;
    request.fields['recipient'] = recipient;
    if (subject != null) request.fields['subject'] = subject;
    request.fields['data'] = jsonEncode(data);

    if (attachments != null) {
      for (final file in attachments) {
        if (await file.exists()) {
          final multipart =
              await http.MultipartFile.fromPath('attachments[]', file.path);
          request.files.add(multipart);
        }
      }
    }

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      try {
        final body = jsonDecode(resp.body);
        return body['success'] == true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Upload a single file using the existing `upload.php` endpoint.
  /// Returns the public URL on success, or null on failure.
  Future<String?> uploadFile(File file) async {
    // Use the new centralized FileUploadService which implements retries,
    // robust normalization, and URL verification.
    final fu = FileUploadService();
    return await fu.uploadFile(file);
  }

  /// Upload raw bytes with filename (web-compatible).
  Future<String?> uploadBytes(List<int> bytes, String filename) async {
    final fu = FileUploadService();
    final res = await fu.uploadBytes(bytes, filename);
    if (res == null) {
      // Throw descriptive exception so callers (UI) can show detailed message
      throw Exception(fu.lastError ?? 'Upload failed');
    }
    return res;
  }

  /// Convenience: send welcome email after registration
  Future<bool> sendWelcomeEmail(
      String recipient, Map<String, String> data) async {
    return sendTemplateEmail('welcome', recipient, data,
        subject: 'Welcome to Manage Care');
  }

  /// Send low stock alert using the 'lowstock' template
  Future<bool> sendLowStockAlert(String recipient, Map<String, String> data,
      {List<File>? attachments}) async {
    return sendTemplateEmail('lowstock', recipient, data,
        subject: 'Low Stock Alert', attachments: attachments);
  }

  /// Send expiry alert using the 'expiry' template
  Future<bool> sendExpiryAlert(String recipient, Map<String, String> data,
      {List<File>? attachments}) async {
    return sendTemplateEmail('expiry', recipient, data,
        subject: 'Expiry Alert', attachments: attachments);
  }

  /// Send subscription payment confirmation using the 'payment' template
  Future<bool> sendSubscriptionPaymentAlert(
      String recipient, Map<String, String> data,
      {List<File>? attachments}) async {
    return sendTemplateEmail('payment', recipient, data,
        subject: 'Payment Confirmation', attachments: attachments);
  }

  /// Send payment reminder / upcoming payment using the 'payment-reminder' template
  Future<bool> sendPaymentReminder(String recipient, Map<String, String> data,
      {List<File>? attachments}) async {
    return sendTemplateEmail('payment-reminder', recipient, data,
        subject: 'Upcoming Payment Reminder', attachments: attachments);
  }

  /// Send order success alert (Pro feature). Must include plan='pro' in the request.
  Future<bool> sendOrderSuccessAlert(
      String recipient, Map<String, dynamic> data,
      {List<File>? attachments, bool isPro = false}) async {
    final uri = Uri.parse('$_base/email_api.php');
    final request = http.MultipartRequest('POST', uri);
    request.fields['api_key'] = _apiKey;
    request.fields['template'] = 'order';
    request.fields['recipient'] = recipient;
    request.fields['data'] = jsonEncode(data);
    // No longer gating order templates on a pro plan: allow sending to all users
    if (attachments != null) {
      for (final file in attachments) {
        if (await file.exists()) {
          final multipart =
              await http.MultipartFile.fromPath('attachments[]', file.path);
          request.files.add(multipart);
        }
      }
    }
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      try {
        final body = jsonDecode(resp.body);
        return body['success'] == true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Send receipt via email (Pro feature) - Uses new receipt_email_listener.php endpoint
  /// Supports theming, PDF generation, business copy, and full customization
  Future<bool> sendReceiptEmail({
    required String recipient,
    required String businessName,
    required String receiptText,
    String? orderId,
    String? businessId,
    String? businessEmail,
    String? businessPhone,
    String? customerName,
    String? logoUrl,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? tax,
    double? total,
    String? paymentMethod,
    List<Map<String, dynamic>>? paymentBreakdown,
    bool isPro = false,
    bool generatePDF = false,
    bool sendCopyToSender = false,
    String theme = 'professional',
    String receiptType = 'detailed',
  }) async {
    final uri = Uri.parse('$_base/receipt_email_listener.php');
    final request = http.MultipartRequest('POST', uri);

    // Authentication and basic fields
    request.fields['api_key'] = _apiKey;
    request.fields['recipient'] = recipient;
    request.fields['businessName'] = businessName;
    request.fields['receiptText'] = receiptText;

    // Optional fields
    if (orderId != null) request.fields['orderId'] = orderId;
    if (businessId != null) request.fields['businessId'] = businessId;
    if (businessEmail != null) request.fields['businessEmail'] = businessEmail;
    if (businessPhone != null) request.fields['businessPhone'] = businessPhone;
    if (customerName != null) request.fields['customerName'] = customerName;
    if (logoUrl != null) request.fields['logoUrl'] = logoUrl;
    // Include structured items if provided so server templates get proper names
    if (items != null) {
      request.fields['itemsJson'] = jsonEncode(items);
      if (subtotal != null) request.fields['subtotal'] = subtotal.toStringAsFixed(2);
      if (tax != null) request.fields['tax'] = tax.toStringAsFixed(2);
      if (total != null) request.fields['total'] = total.toStringAsFixed(2);
      if (paymentMethod != null) request.fields['paymentMethod'] = paymentMethod;
      // Also try to include a pre-rendered HTML version for richer clients
      try {
        final emailHtml = EmailTemplateService.generateReceiptEmailHtml(
          businessName: businessName,
          businessLogo: logoUrl,
          businessContact: businessPhone,
          receiptNumber: orderId ?? '',
          receiptDate: DateTime.now(),
          customerName: customerName ?? 'Valued Customer',
          items: items,
          subtotal: subtotal ?? 0.0,
          tax: tax ?? 0.0,
          total: total ?? 0.0,
          paymentMethod: paymentMethod ?? 'Cash',
          paymentBreakdown: paymentBreakdown,
          customHeader: '', customFooter: '',
        );
        request.fields['emailHtml'] = emailHtml;
      } catch (e) {
        // If template generation fails, continue without emailHtml
        print('Failed to generate emailHtml locally: $e');
      }
    }

    // Feature flags: do not gate on pro status; allow generatePDF for any user that requests it
    if (generatePDF) request.fields['generatePDF'] = 'true';
    if (sendCopyToSender && businessEmail != null) {
      request.fields['sendCopy'] = 'true';
    }

    // Customization
    request.fields['theme'] = theme;
    request.fields['receiptType'] = receiptType;

    try {
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        try {
          final body = jsonDecode(resp.body);
          return body['success'] == true;
        } catch (e) {
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error sending receipt email: $e');
      return false;
    }
  }

  /// Send receipt with full tracking and archiving (Pro feature)
  /// Returns receipt ID for tracking purposes
  Future<Map<String, dynamic>?> sendReceiptEmailWithTracking({
    required String recipient,
    required String businessName,
    required String receiptText,
    String? orderId,
    String? businessId,
    bool isPro = false,
    Map<String, String>? additionalData,
  }) async {
    final success = await sendReceiptEmail(
      recipient: recipient,
      businessName: businessName,
      receiptText: receiptText,
      orderId: orderId,
      businessId: businessId,
      isPro: isPro,
      customerName: additionalData?['customerName'],
      businessEmail: additionalData?['businessEmail'],
      businessPhone: additionalData?['businessPhone'],
      logoUrl: additionalData?['logoUrl'],
    );

    if (!success) return null;

    return {
      'success': true,
      'recipient': recipient,
      'businessName': businessName,
      'orderId': orderId,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Send worker invitation email with credentials and role info
  Future<bool> sendWorkerInvitationEmail(
      String recipient, Map<String, String> data) async {
    return sendTemplateEmail('worker-invitation', recipient, data,
        subject: 'You have been invited to join ${data['businessName']}');
  }
}

