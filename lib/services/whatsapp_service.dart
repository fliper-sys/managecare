import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:business_manager/core/utils/formatters.dart';
import 'package:http/http.dart' as http;

import 'notification_and_email_service.dart';
import '../core/config.dart';
import 'email_service.dart'; 

/// Simple WhatsApp messaging helper using the WhatsApp Cloud API (Meta)
///
/// Usage:
/// - Store `whatsappPhoneNumberId` and `whatsappAccessToken` on the
///   `businesses/{businessId}` document (recommended).
/// - Optionally store `ownerWhatsappNumber` as the recipient number.
///
class WhatsAppService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationAndEmailService _logger = NotificationAndEmailService();

  /// Send a text notification to the business owner for a new order.
  /// If `to` is omitted, this will try to read `ownerWhatsappNumber` from
  /// the business document.
  Future<bool> sendOrderNotification({
    required String businessId,
    required String orderId,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final doc =
          await _firestore.collection('businesses').doc(businessId).get();
      if (!doc.exists) {
        await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'order',
            channel: 'whatsapp',
            recipient: 'unknown',
            success: false,
            orderId: orderId,
            errorMessage: 'business document not found');
        return false;
      }

      final data = doc.data() ?? {};
      // Support storing credentials at top-level or inside `settings` map
      final settings = (data['settings'] as Map<String, dynamic>?) ?? {};
      var phoneNumberId = (data['whatsappPhoneNumberId'] as String?) ??
          (settings['whatsappPhoneNumberId'] as String?);
      var accessToken = (data['whatsappAccessToken'] as String?) ??
          (settings['whatsappAccessToken'] as String?);
      var to = (data['ownerWhatsappNumber'] as String?) ??
          (settings['ownerWhatsappNumber'] as String?);

      // Final fallback to hard-coded app config (for testing only)
      phoneNumberId ??= AppConfig.whatsappPhoneNumberId.isNotEmpty
          ? AppConfig.whatsappPhoneNumberId
          : null;
      accessToken ??= AppConfig.whatsappAccessToken.isNotEmpty
          ? AppConfig.whatsappAccessToken
          : null;
      to ??= AppConfig.ownerWhatsappNumber.isNotEmpty
          ? AppConfig.ownerWhatsappNumber
          : null;

      if (phoneNumberId == null || accessToken == null) {
        await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'order',
            channel: 'whatsapp',
            recipient: to is String ? to : 'unknown',
            success: false,
            orderId: orderId,
            errorMessage:
                'whatsappPhoneNumberId or whatsappAccessToken missing on business doc');
        return false;
      }

      // support multiple recipients: check for list in settings
      List<String> recipients = [];
      if (settings['ownerWhatsappNumbers'] != null) {
        final raw = settings['ownerWhatsappNumbers'];
        if (raw is List) {
          recipients = raw.map((e) => e.toString()).toList();
        }
      } else if (to != null) {
        // single recipient fallback
        recipients = [to.toString()];
      }

      // final fallback to AppConfig owner's single number
      if (recipients.isEmpty && AppConfig.ownerWhatsappNumber.isNotEmpty) {
        recipients = [AppConfig.ownerWhatsappNumber];
      }

      if (recipients.isEmpty) {
        await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'order',
            channel: 'whatsapp',
            recipient: 'none',
            success: false,
            orderId: orderId,
            errorMessage: 'No recipient numbers configured');
        return false;
      }

      final itemList = items
          .map((i) =>
              '${i['name'] ?? i['drinkId'] ?? ''} x${i['quantity'] ?? i['qty'] ?? 1}')
          .join(', ');

      final message =
          'New order: $orderId\nTotal: ${formatCurrency(total)}\nItems: $itemList';
      final url =
          Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages');

      bool anySuccess = false;
      for (var rawRecipient in recipients) {
        try {
          var r = rawRecipient.replaceAll(RegExp(r'[^0-9]'), '');
          if (r.isEmpty) continue;

          final body = jsonEncode({
            'messaging_product': 'whatsapp',
            'to': r,
            'type': 'text',
            'text': {'body': message}
          });

          final resp = await http.post(url,
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json'
              },
              body: body);

          final success = resp.statusCode >= 200 && resp.statusCode < 300;
          anySuccess = anySuccess || success;

          await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'order',
            channel: 'whatsapp',
            recipient: r,
            success: success,
            orderId: orderId,
            errorMessage: success ? null : resp.body,
          );
        } catch (e) {
          await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'order',
            channel: 'whatsapp',
            recipient: rawRecipient.toString(),
            success: false,
            orderId: orderId,
            errorMessage: e.toString(),
          );
        }
      }

      return anySuccess;
    } catch (e) {
      try {
        await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'order',
            channel: 'whatsapp',
            recipient: 'unknown',
            success: false,
            orderId: orderId,
            errorMessage: e.toString());
      } catch (_) {}
      return false;
    }
  }

  /// Send plain text message(s) to an arbitrary list of phone numbers using the
  /// configured WhatsApp Cloud credentials on the business doc. This is useful
  /// for sending customer messages such as appointment reminders or short
  /// announcements. Returns true if at least one message was delivered.
  Future<bool> sendTextToNumbers({
    required String businessId,
    required List<String> toNumbers,
    required String message,
  }) async {
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).get();
      if (!doc.exists) return false;
      final data = doc.data() ?? {};
      final settings = (data['settings'] as Map<String, dynamic>?) ?? {};
      var phoneNumberId = (data['whatsappPhoneNumberId'] as String?) ?? (settings['whatsappPhoneNumberId'] as String?);
      var accessToken = (data['whatsappAccessToken'] as String?) ?? (settings['whatsappAccessToken'] as String?);

      phoneNumberId ??= AppConfig.whatsappPhoneNumberId.isNotEmpty ? AppConfig.whatsappPhoneNumberId : null;
      accessToken ??= AppConfig.whatsappAccessToken.isNotEmpty ? AppConfig.whatsappAccessToken : null;

      if (phoneNumberId == null || accessToken == null) return false;

      final url = Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages');

      bool anySuccess = false;
      for (var raw in toNumbers) {
        try {
          var r = raw.replaceAll(RegExp(r'[^0-9]'), '');
          if (r.isEmpty) continue;

          final body = jsonEncode({
            'messaging_product': 'whatsapp',
            'to': r,
            'type': 'text',
            'text': {'body': message}
          });

          final resp = await http.post(url, headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json'
          }, body: body);

          final success = resp.statusCode >= 200 && resp.statusCode < 300;
          anySuccess = anySuccess || success;

          await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'customer_messages',
            channel: 'whatsapp',
            recipient: r,
            success: success,
            errorMessage: success ? null : resp.body,
          );
        } catch (e) {
          await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'customer_messages',
            channel: 'whatsapp',
            recipient: raw,
            success: false,
            errorMessage: e.toString(),
          );
        }
      }

      return anySuccess;
    } catch (e) {
      return false;
    }
  }

  /// Send text message to configured business owner(s). It reads owner numbers
  /// from business doc (ownerWhatsappNumbers / ownerWhatsappNumber) or falls
  /// back to AppConfig.ownerWhatsappNumber.
  Future<bool> sendTextToOwners({required String businessId, required String message}) async {
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).get();
      if (!doc.exists) return false;
      final data = doc.data() ?? {};
      final settings = (data['settings'] as Map<String, dynamic>?) ?? {};
      List<String> recipients = [];
      if (settings['ownerWhatsappNumbers'] != null && settings['ownerWhatsappNumbers'] is List) {
        recipients = (settings['ownerWhatsappNumbers'] as List).map((e) => e.toString()).toList();
      } else if ((settings['ownerWhatsappNumber'] as String?) != null) {
        recipients = [(settings['ownerWhatsappNumber'] as String)];
      } else if ((data['ownerWhatsappNumber'] as String?) != null) {
        recipients = [(data['ownerWhatsappNumber'] as String)];
      }
      if (recipients.isEmpty && AppConfig.ownerWhatsappNumber.isNotEmpty) recipients = [AppConfig.ownerWhatsappNumber];
      if (recipients.isEmpty) return false;
      return await sendTextToNumbers(businessId: businessId, toNumbers: recipients, message: message);
    } catch (e) {
      return false;
    }
  }

  /// Send recent transactions summary via WhatsApp (up to `limit` items) and email a detailed list to owner
  Future<bool> sendRecentTransactions({
    required String businessId,
    String? to,
    int limit = 30,
    String? webhookUrl,
  }) async {
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).get();
      if (!doc.exists) {
        await _logger.logNotificationEvent(
          businessId: businessId,
          type: 'transactions_summary',
          channel: 'whatsapp',
          recipient: to ?? 'unknown',
          success: false,
          errorMessage: 'Business document not found',
        );
        return false;
      }

      final data = doc.data() ?? {};
      final settings = (data['settings'] as Map<String, dynamic>?) ?? {};
      var phoneNumberId = (data['whatsappPhoneNumberId'] as String?) ??
          (settings['whatsappPhoneNumberId'] as String?);
      var accessToken = (data['whatsappAccessToken'] as String?) ??
          (settings['whatsappAccessToken'] as String?);

      phoneNumberId ??= AppConfig.whatsappPhoneNumberId.isNotEmpty
          ? AppConfig.whatsappPhoneNumberId
          : null;
      accessToken ??= AppConfig.whatsappAccessToken.isNotEmpty
          ? AppConfig.whatsappAccessToken
          : null;

      // Build recipients list (supports ownerWhatsappNumbers or single ownerWhatsappNumber)
      List<String> recipients = [];
      if (settings['ownerWhatsappNumbers'] != null) {
        final raw = settings['ownerWhatsappNumbers'];
        if (raw is List) recipients = raw.map((e) => e.toString()).toList();
      } else if ((settings['ownerWhatsappNumber'] as String?) != null) {
        recipients = [(settings['ownerWhatsappNumber'] as String)];
      } else if (to != null) {
        recipients = [to];
      }
      if (recipients.isEmpty && AppConfig.ownerWhatsappNumber.isNotEmpty) {
        recipients = [AppConfig.ownerWhatsappNumber];
      }

      if (phoneNumberId == null || accessToken == null || recipients.isEmpty) {
        await _logger.logNotificationEvent(
          businessId: businessId,
          type: 'transactions_summary',
          channel: 'whatsapp',
          recipient: recipients.isNotEmpty ? recipients.join(',') : 'none',
          success: false,
          errorMessage: 'WhatsApp credentials or recipients missing',
        );
        return false;
      }

      // Query recent transactions
      final txQuery = await _firestore
          .collection('payment_transactions')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> txs = [];
      for (final tdoc in txQuery.docs) {
        final td = tdoc.data();
        final created = parseTimestamp(td['createdAt']);
        txs.add({
          'transactionId': td['transactionId'] ?? tdoc.id,
          'amount': (td['amount'] ?? 0).toString(),
          'status': td['status'] ?? '',
          'createdAt': created.toIso8601String(),
          'email': td['email'] ?? '',
        });
      }

      final businessName = data['name'] ?? 'Your business';
      String message;
      if (txs.isEmpty) {
        message = 'No recent transactions found for "$businessName".'
            '\nWe will email you a detailed report if available.';
      } else {
        // accounting summary
        double totalAmount = 0.0;
        final statusCounts = <String, int>{};
        for (final tx in txs) {
          totalAmount += double.tryParse(tx['amount'].toString()) ?? 0.0;
          final st = (tx['status'] ?? 'unknown').toString();
          statusCounts[st] = (statusCounts[st] ?? 0) + 1;
        }

        // Compute profit: sum of sales totals - sum of cost price * qty (COGS)
        double sampledSalesTotal = 0.0;
        double sampledCostTotal = 0.0;
        try {
          final salesSnapshot = await _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('sales')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

          for (final sDoc in salesSnapshot.docs) {
            final s = sDoc.data();
            final items = (s['items'] as List<dynamic>?) ?? [];
            for (final it in items) {
              final qty = (it['quantity'] as num?)?.toDouble() ?? (it['qty'] as num?)?.toDouble() ?? 0.0;
              final unitPrice = (it['unitPrice'] as num?)?.toDouble() ?? (it['price'] as num?)?.toDouble() ?? 0.0;
              sampledSalesTotal += unitPrice * qty;

              final pid = (it['productId'] as String?) ?? '';
              double costPrice = 0.0;
              if (pid.isNotEmpty) {
                try {
                  final invDoc = await _firestore
                      .collection('businesses')
                      .doc(businessId)
                      .collection('inventory')
                      .doc(pid)
                      .get();
                  if (invDoc.exists) {
                    final inv = invDoc.data();
                    costPrice = (inv?['costPrice'] as num?)?.toDouble() ?? (inv?['unitCost'] as num?)?.toDouble() ?? 0.0;
                  }
                } catch (_) {}
              }

              sampledCostTotal += costPrice * qty;
            }
          }
        } catch (e) {
          print('[WhatsAppService] Failed to compute profit from sales: $e');
        }

        final profitSampled = sampledSalesTotal - sampledCostTotal;

        final lines = <String>[];
        for (var i = 0; i < txs.length && i < limit; i++) {
          final tx = txs[i];
          final amt = double.tryParse(tx['amount'].toString()) ?? 0.0;
          final dateStr = (tx['createdAt'] != null && tx['createdAt'].toString().isNotEmpty)
              ? parseTimestamp(tx['createdAt']).toLocal().toString().split('.').first
              : '';
          final who = (tx['cashier'] as String?)?.toString() ?? (tx['email'] as String?)?.toString() ?? '';
          lines.add('${i + 1}. ₦${amt.toStringAsFixed(2)} • ${tx['status']} • $dateStr${who.isNotEmpty ? ' • $who' : ''}');
        }

        final statusSummary = statusCounts.entries.map((e) => '${e.key}: ${e.value}').join(', ');

        message = 'Daily transactions (showing up to ${limit}) for "$businessName"\n'
          'Total (sampled): ₦${totalAmount.toStringAsFixed(2)} • Transactions: ${txs.length}\n'
          'Status breakdown: $statusSummary\n'
          'Profit (sampled): ₦${profitSampled.toStringAsFixed(2)}\n\n'
          '${lines.join('\n')}\n\nNote: Transaction IDs are omitted for privacy. A detailed report (including IDs) has been emailed to the owner.';
      }

      final url = Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages');

      // Optional webhook: POST the full transaction payload (best-effort)
      if (webhookUrl != null && webhookUrl.isNotEmpty) {
        try {
          final hookBody = jsonEncode({
            'businessId': businessId,
            'businessName': businessName,
            'date': DateTime.now().toIso8601String(),
            'total': txs.fold<double>(0.0, (s, t) => s + (double.tryParse(t['amount'].toString()) ?? 0.0)),
            'count': txs.length,
            'transactions': txs,
          });
          // Fire-and-forget (include optional hook token header)
          final hookHeaders = {'Content-Type': 'application/json'};
          final hookToken = (settings['dailyReportWebhookToken'] as String?) ?? (AppConfig.dailyReportHookToken.isNotEmpty ? AppConfig.dailyReportHookToken : null);
          if (hookToken != null && hookToken.isNotEmpty) {
            hookHeaders['X-Hook-Token'] = hookToken;
          }
          http.post(Uri.parse(webhookUrl), headers: hookHeaders, body: hookBody).then((r) {
            if (r.statusCode < 200 || r.statusCode >= 300) {
              print('[WhatsAppService] webhook POST failed: ${r.statusCode} ${r.body}');
            }
          }).catchError((e) {
            print('[WhatsAppService] webhook POST error: $e');
          });
        } catch (e) {
          print('[WhatsAppService] webhook build error: $e');
        }
      }

      bool anySuccess = false;
      for (var rawRecipient in recipients) {
        try {
          var r = rawRecipient.replaceAll(RegExp(r'[^0-9]'), '');
          if (r.isEmpty) continue;

          final body = jsonEncode({
            'messaging_product': 'whatsapp',
            'to': r,
            'type': 'text',
            'text': {'body': message}
          });

          final resp = await http.post(url,
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json'
              },
              body: body);

          final success = resp.statusCode >= 200 && resp.statusCode < 300;
          anySuccess = anySuccess || success;

          await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'transactions_summary',
            channel: 'whatsapp',
            recipient: r,
            success: success,
            errorMessage: success ? null : resp.body,
          );
        } catch (e) {
          await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'transactions_summary',
            channel: 'whatsapp',
            recipient: rawRecipient.toString(),
            success: false,
            errorMessage: e.toString(),
          );
        }
      }

      // Send detailed email to owner (best-effort)
      try {
        String? ownerEmail;
        if (data['ownerEmail'] != null && data['ownerEmail'].toString().isNotEmpty) {
          ownerEmail = data['ownerEmail'].toString();
        } else if (data['ownerId'] != null) {
          final ownerDoc = await _firestore.collection('users').doc(data['ownerId']).get();
          if (ownerDoc.exists) {
            ownerEmail = (ownerDoc.data() as Map<String, dynamic>)['email'] as String?;
          }
        }

        if (ownerEmail != null && ownerEmail.isNotEmpty) {
          final emailService = EmailService();
          final txSummary = txs.map((t) => '${t['transactionId']} - ₦${double.tryParse(t['amount'].toString())?.toStringAsFixed(2) ?? '0.00'} - ${t['status']} - ${t['createdAt']}').join('\n');
          await emailService.sendTemplateEmail(
            'daily_transactions',
            ownerEmail,
            {
              'businessName': businessName,
              'transactions': txSummary,
              'count': txs.length.toString(),
            },
            subject: 'Daily Transactions - $businessName',
          );
        }
      } catch (e) {
        print('[WhatsAppService] Warning: failed to email transactions: $e');
      }

      return anySuccess;
    } catch (e) {
      try {
        await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'transactions_summary',
            channel: 'whatsapp',
            recipient: 'unknown',
            success: false,
            errorMessage: e.toString());
      } catch (_) {}
      return false;
    }
  }
}