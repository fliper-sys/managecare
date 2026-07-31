import 'dart:convert';
import 'package:business_manager/core/utils/datetime_utils.dart';
import 'package:business_manager/core/utils/formatters.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'notification_and_email_service.dart';
import 'managecare_api_client.dart';
import '../core/config.dart';
import 'email_service.dart';

/// Simple WhatsApp messaging helper using the WhatsApp Cloud API (Meta)
///
/// Usage:
/// - Store `whatsappPhoneNumberId` and `whatsappAccessToken` in the
///   `businesses.settings` JSONB column (recommended).
/// - Optionally store `ownerWhatsappNumber` as the recipient number.
///
class WhatsAppService {
  final NotificationAndEmailService _logger = NotificationAndEmailService();

  /// Fetches a business row from the backend. Returns null if not found
  /// or unreachable (callers already treat a missing business as a no-op).
  Future<Map<String, dynamic>?> _fetchBusiness(String businessId) async {
    try {
      final response =
          await ManagecareApiClient.instance.get('/api/businesses/$businessId');
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return null;
    }
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
    return 0.0;
  }

  double _saleItemQuantity(Map<String, dynamic> item) {
    final quantity = _readDouble(item['quantity']);
    if (quantity > 0) return quantity;
    final qty = _readDouble(item['qty']);
    if (qty > 0) return qty;
    final multiplier = _readDouble(item['saleUnitMultiplier']);
    if (multiplier > 0) return multiplier;
    return 1.0;
  }

  String _saleItemModeLabel(Map<String, dynamic> item) {
    final mode = (item['pricingMode'] ??
            item['saleMode'] ??
            item['saleUnit'] ??
            item['pricingType'])
        ?.toString()
        .toLowerCase()
        .trim();
    final multiplier = _readDouble(item['saleUnitMultiplier']);
    if (mode != null && mode.isNotEmpty) {
      if (mode.contains('whole') || mode.contains('bulk')) return 'Wholesale';
      if (mode.contains('retail')) return 'Retail';
      if (mode.contains('service')) return 'Service';
      return mode[0].toUpperCase() + mode.substring(1);
    }
    if (multiplier > 1) return 'Wholesale';
    return 'Retail';
  }

  Future<double> _saleItemCostPerUnit(
    String businessId,
    Map<String, dynamic> item,
  ) async {
    final directCandidates = [
      item['costPrice'],
      item['cost'],
      item['unitCost'],
      item['purchasePrice'],
      item['inventoryCost'],
    ];
    for (final candidate in directCandidates) {
      final value = _readDouble(candidate);
      if (value > 0) return value;
    }

    final inventoryId = (item['productId'] ??
            item['inventoryId'] ??
            item['itemId'] ??
            item['skuId'])
        ?.toString()
        .trim();

    if (inventoryId!.isNotEmpty) {
      try {
        final response = await ManagecareApiClient.instance
            .get('/api/inventory/$businessId/$inventoryId');
        final inv = Map<String, dynamic>.from(response as Map);
        final value = _readDouble(inv['cost_price']);
        if (value > 0) return value;
      } catch (_) {}
    }

    return 0.0;
  }

  bool _isFuelStationBusiness(Map<String, dynamic> businessData) {
    final businessType = (businessData['business_type'] ??
            businessData['businessType'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    return businessType.contains('petroleum') ||
        businessType.contains('petrol') ||
        businessType.contains('gas station') ||
        businessType.contains('fuel station') ||
        businessType.contains('gas');
  }

  Future<String> _buildPetrolDailyTransactionsMessage({
    required String businessId,
    required String businessName,
    required DateTime date,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final pumpsResponse = await ManagecareApiClient.instance
        .get('/api/pumps/$businessId/pumps', query: {'isActive': 'true'});
    final pumpConfigRows =
        ((pumpsResponse['data'] as List?) ?? []).cast<Map<String, dynamic>>();

    final uploadsResponse = await ManagecareApiClient.instance.get(
      '/api/pumps/$businessId/uploads',
      query: {
        'from': start.toIso8601String(),
        'to': end.toIso8601String(),
        'limit': '500',
      },
    );
    final uploadRows =
        ((uploadsResponse['data'] as List?) ?? []).cast<Map<String, dynamic>>();

    final salesResponse = await ManagecareApiClient.instance.get(
      '/api/sales/$businessId',
      query: {
        'startDate': start.toIso8601String(),
        'endDate': end.toIso8601String(),
        'limit': '500',
      },
    );
    final saleRows =
        ((salesResponse['data'] as List?) ?? []).cast<Map<String, dynamic>>();

    final pumpEntries = <Map<String, dynamic>>[];
    for (final data in pumpConfigRows) {
      pumpEntries.add({
        'id': data['id']?.toString() ?? '',
        'pumpNumber': data['pump_number']?.toString() ?? '',
        'productName': data['product_name']?.toString() ?? 'Fuel',
      });
    }

    final uploadsByPumpKey = <String, List<Map<String, dynamic>>>{};
    for (final data in uploadRows) {
      final pumpNumber = data['pump_number']?.toString() ?? '';
      final pumpId = data['pump_id']?.toString() ?? '';
      final key = pumpId.isNotEmpty
          ? pumpId
          : (pumpNumber.isNotEmpty ? 'number:$pumpNumber' : 'unknown');
      uploadsByPumpKey.putIfAbsent(key, () => []).add({
        'soldVolume': data['sold_volume'],
        'expectedAmount': data['expected_amount'],
        'workerName': data['worker_name'],
        'workerId': data['worker_id'],
      });
    }

    // The `sales` table has no fuel/category or pump linkage - a POS retail
    // sale can't be attributed to a specific pump. Pump revenue is captured
    // entirely by pump_daily_uploads (above); this stays empty rather than
    // guessing, so the section honestly reads "no pump sales recorded".
    final fuelSalesByPumpKey = <String, List<Map<String, dynamic>>>{};

    final normalizedSales = saleRows
        .map((data) => {
              'totalAmount': data['total_amount'],
              'finalAmount': data['final_amount'],
              'paymentMethod': data['payment_method'],
              'workerName': data['worker_name'],
              'workerId': data['worker_id'],
              'items': data['items'],
              'createdAt': data['created_at'],
            })
        .toList();

    final sortedPumpEntries = List<Map<String, dynamic>>.from(pumpEntries)
      ..sort((a, b) {
        final aNumber = double.tryParse(a['pumpNumber']?.toString() ?? '');
        final bNumber = double.tryParse(b['pumpNumber']?.toString() ?? '');
        if (aNumber != null && bNumber != null) {
          return aNumber.compareTo(bNumber);
        }
        return (a['pumpNumber']?.toString() ?? '')
            .compareTo(b['pumpNumber']?.toString() ?? '');
      });

    final buffer = StringBuffer();
    buffer.writeln('Daily transactions for "$businessName"');
    buffer.writeln('Date: ${DateFormat.yMMMMd().format(date)}');
    buffer.writeln('');
    buffer.writeln('PUMP UPLOADS');

    if (sortedPumpEntries.isEmpty && uploadsByPumpKey.isEmpty) {
      buffer.writeln('- No pump configurations or uploads found for today.');
    } else {
      final seenPumpKeys = <String>{};
      for (final pump in sortedPumpEntries) {
        final pumpNumber = pump['pumpNumber']?.toString() ?? '';
        final pumpLabel = pumpNumber.isNotEmpty
            ? 'Pump $pumpNumber'
            : 'Pump ${pump['id']?.toString() ?? ''}';
        final pumpKey = pump['id']?.toString().isNotEmpty == true
            ? pump['id'].toString()
            : (pumpNumber.isNotEmpty ? 'number:$pumpNumber' : 'unknown');
        seenPumpKeys.add(pumpKey);

        final uploads = uploadsByPumpKey[pumpKey] ?? const <Map<String, dynamic>>[];
        if (uploads.isEmpty) {
          buffer.writeln('- $pumpLabel: no upload recorded');
          continue;
        }

        final totalVolume = uploads.fold<double>(0.0, (sum, upload) {
          final value = _readDouble(upload['soldVolume']);
          return sum + value;
        });
        final totalAmount = uploads.fold<double>(0.0, (sum, upload) {
          final value = _readDouble(upload['expectedAmount']);
          return sum + value;
        });

        buffer.writeln(
          '- $pumpLabel: ${totalVolume.toStringAsFixed(3)}L • ${formatCurrency(totalAmount)}',
        );

        final workerSummaries = <String, Map<String, dynamic>>{};
        for (final upload in uploads) {
          final workerName = (upload['workerName'] ?? upload['workerId'] ?? 'Unknown')
              .toString();
          final existing = workerSummaries[workerName] ?? {
            'volume': 0.0,
            'amount': 0.0,
          };
          existing['volume'] = _readDouble(existing['volume']) + _readDouble(upload['soldVolume']);
          existing['amount'] = _readDouble(existing['amount']) + _readDouble(upload['expectedAmount']);
          workerSummaries[workerName] = existing;
        }

        for (final entry in workerSummaries.entries.toList()) {
          final workerName = entry.key;
          final summary = entry.value;
          final volume = _readDouble(summary['volume']);
          final amount = _readDouble(summary['amount']);
          buffer.writeln(
            '  • $workerName: ${volume.toStringAsFixed(3)}L • ${formatCurrency(amount)}',
          );
        }
      }

      final uploadOnlyPumps = uploadsByPumpKey.entries.where((entry) {
        final key = entry.key;
        return !seenPumpKeys.contains(key);
      }).toList();
      for (final entry in uploadOnlyPumps) {
        final pumpNumber = entry.key.startsWith('number:')
            ? entry.key.substring('number:'.length)
            : entry.key;
        final uploads = entry.value;
        final totalVolume = uploads.fold<double>(0.0, (sum, upload) {
          return sum + _readDouble(upload['soldVolume']);
        });
        final totalAmount = uploads.fold<double>(0.0, (sum, upload) {
          return sum + _readDouble(upload['expectedAmount']);
        });
        buffer.writeln('- Pump $pumpNumber: ${totalVolume.toStringAsFixed(3)}L • ${formatCurrency(totalAmount)}');
        final workerSummaries = <String, Map<String, dynamic>>{};
        for (final upload in uploads) {
          final workerName = (upload['workerName'] ?? upload['workerId'] ?? 'Unknown')
              .toString();
          final existing = workerSummaries[workerName] ?? {
            'volume': 0.0,
            'amount': 0.0,
          };
          existing['volume'] = _readDouble(existing['volume']) + _readDouble(upload['soldVolume']);
          existing['amount'] = _readDouble(existing['amount']) + _readDouble(upload['expectedAmount']);
          workerSummaries[workerName] = existing;
        }
        for (final entry in workerSummaries.entries.toList()) {
          final workerName = entry.key;
          final summary = entry.value;
          buffer.writeln(
            '  • $workerName: ${_readDouble(summary['volume']).toStringAsFixed(3)}L • ${formatCurrency(_readDouble(summary['amount']))}',
          );
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('PUMP SALES');

    if (sortedPumpEntries.isEmpty && fuelSalesByPumpKey.isEmpty) {
      buffer.writeln('- No pump sales recorded for today.');
    } else {
      final seenPumpKeys = <String>{};
      for (final pump in sortedPumpEntries) {
        final pumpNumber = pump['pumpNumber']?.toString() ?? '';
        final pumpLabel = pumpNumber.isNotEmpty
            ? 'Pump $pumpNumber'
            : 'Pump ${pump['id']?.toString() ?? ''}';
        final pumpKey = pump['id']?.toString().isNotEmpty == true
            ? pump['id'].toString()
            : (pumpNumber.isNotEmpty ? 'number:$pumpNumber' : 'unknown');
        seenPumpKeys.add(pumpKey);

        final sales = fuelSalesByPumpKey[pumpKey] ?? const <Map<String, dynamic>>[];
        if (sales.isEmpty) {
          buffer.writeln('- $pumpLabel: no pump sales recorded');
          continue;
        }

        final totalAmount = sales.fold<double>(0.0, (sum, sale) {
          return sum + (_readDouble(sale['totalAmount']) > 0
              ? _readDouble(sale['totalAmount'])
              : _readDouble(sale['finalAmount']) > 0
                  ? _readDouble(sale['finalAmount'])
                  : _readDouble(sale['total']));
        });
        buffer.writeln('- $pumpLabel: ${formatCurrency(totalAmount)}');

        final workerSummaries = <String, Map<String, dynamic>>{};
        for (final sale in sales) {
          final workerName = (sale['workerName'] ?? sale['workerId'] ?? 'Unknown').toString();
          final existing = workerSummaries[workerName] ?? {'amount': 0.0};
          existing['amount'] = _readDouble(existing['amount']) + (_readDouble(sale['totalAmount']) > 0
              ? _readDouble(sale['totalAmount'])
              : _readDouble(sale['finalAmount']) > 0
                  ? _readDouble(sale['finalAmount'])
                  : _readDouble(sale['total']));
          workerSummaries[workerName] = existing;
        }

        for (final entry in workerSummaries.entries.toList()) {
          final workerName = entry.key;
          final amount = _readDouble(entry.value['amount']);
          buffer.writeln('  • $workerName: ${formatCurrency(amount)}');
        }
      }

      final salesOnlyPumps = fuelSalesByPumpKey.entries.where((entry) {
        return !seenPumpKeys.contains(entry.key);
      }).toList();
      for (final entry in salesOnlyPumps) {
        final pumpNumber = entry.key.startsWith('number:')
            ? entry.key.substring('number:'.length)
            : entry.key;
        final sales = entry.value;
        final totalAmount = sales.fold<double>(0.0, (sum, sale) {
          return sum + (_readDouble(sale['totalAmount']) > 0
              ? _readDouble(sale['totalAmount'])
              : _readDouble(sale['finalAmount']) > 0
                  ? _readDouble(sale['finalAmount'])
                  : _readDouble(sale['total']));
        });
        buffer.writeln('- Pump $pumpNumber: ${formatCurrency(totalAmount)}');
        final workerSummaries = <String, Map<String, dynamic>>{};
        for (final sale in sales) {
          final workerName = (sale['workerName'] ?? sale['workerId'] ?? 'Unknown').toString();
          final existing = workerSummaries[workerName] ?? {'amount': 0.0};
          existing['amount'] = _readDouble(existing['amount']) + (_readDouble(sale['totalAmount']) > 0
              ? _readDouble(sale['totalAmount'])
              : _readDouble(sale['finalAmount']) > 0
                  ? _readDouble(sale['finalAmount'])
                  : _readDouble(sale['total']));
          workerSummaries[workerName] = existing;
        }
        for (final entry in workerSummaries.entries.toList()) {
          final workerName = entry.key;
          final amount = _readDouble(entry.value['amount']);
          buffer.writeln('  • $workerName: ${formatCurrency(amount)}');
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('MINI MART SALES');

    // The `sales` table has no fuel/category distinction, and fuel revenue
    // is tracked separately via pump_daily_uploads (above) - so every POS
    // sale for the day is a mini-mart sale here.
    final miniMartSales = normalizedSales;

    double miniMartTotal = 0.0;
    for (final sale in miniMartSales) {
      miniMartTotal += _readDouble(sale['totalAmount']) > 0
          ? _readDouble(sale['totalAmount'])
          : _readDouble(sale['finalAmount']) > 0
              ? _readDouble(sale['finalAmount'])
              : _readDouble(sale['total']);
    }

    buffer.writeln('Total sales: ${formatCurrency(miniMartTotal)}');
    if (miniMartSales.isEmpty) {
      buffer.writeln('- No mini mart sales recorded today.');
    } else {
      for (final sale in miniMartSales.take(10)) {
        final saleTime = parseTimestamp(sale['createdAt']).toLocal();
        final saleTotal = _readDouble(sale['totalAmount']) > 0
            ? _readDouble(sale['totalAmount'])
            : _readDouble(sale['finalAmount']) > 0
                ? _readDouble(sale['finalAmount'])
                : _readDouble(sale['total']);
        final paymentMethod = (sale['paymentMethod'] ?? 'Cash').toString();
        final workerName = (sale['workerName'] ?? sale['workerId'] ?? 'Unknown').toString();
        final items = (sale['items'] as List<dynamic>?) ?? [];
        final itemSummary = items.isEmpty
            ? 'No item details'
            : items.take(3).map((item) {
                if (item is Map) {
                  final product = (item['productName'] ?? item['product_name'] ?? item['name'] ?? 'Item').toString();
                  final qty = _readDouble(item['quantity']).toStringAsFixed(0);
                  return '$product x$qty';
                }
                return item.toString();
              }).join(', ');
        buffer.writeln(
          '- ${DateFormat.jm().format(saleTime)} • ${formatCurrency(saleTotal)} • $paymentMethod • $workerName',
        );
        buffer.writeln('  Items: $itemSummary');
      }
    }

    return buffer.toString();
  }

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
      final data = await _fetchBusiness(businessId);
      if (data == null) {
        await _logger.logNotificationEvent(
            businessId: businessId,
            type: 'order',
            channel: 'whatsapp',
            recipient: 'unknown',
            success: false,
            orderId: orderId,
            errorMessage: 'business not found');
        return false;
      }

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
      final data = await _fetchBusiness(businessId);
      if (data == null) return false;
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
      final data = await _fetchBusiness(businessId);
      if (data == null) return false;
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
      final data = await _fetchBusiness(businessId);
      if (data == null) {
        await _logger.logNotificationEvent(
          businessId: businessId,
          type: 'transactions_summary',
          channel: 'whatsapp',
          recipient: to ?? 'unknown',
          success: false,
          errorMessage: 'Business not found',
        );
        return false;
      }

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

      List<String> recipients = [];
      if (settings['ownerWhatsappNumbers'] != null) {
        final raw = settings['ownerWhatsappNumbers'];
        if (raw is List) {
          recipients = raw.map((e) => e.toString()).toList();
        }
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

      final txRows = await Supabase.instance.client
          .from('payment_transactions')
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false)
          .limit(limit);

      final List<Map<String, dynamic>> txs = [];
      for (final td in txRows) {
        final created = parseTimestamp(td['created_at']);
        txs.add({
          'transactionId': td['transaction_id'] ?? td['id'],
          'amount': (td['amount'] ?? 0).toString(),
          'status': td['status'] ?? '',
          'createdAt': created.toIso8601String(),
          'email': td['email'] ?? '',
        });
      }

      final businessName = data['name'] ?? 'Your business';
      String message;
      if (_isFuelStationBusiness(data)) {
        message = await _buildPetrolDailyTransactionsMessage(
          businessId: businessId,
          businessName: businessName,
          date: DateTime.now(),
        );
      } else if (txs.isEmpty) {
        message = 'No recent transactions found for "$businessName".\n'
            'We will email you a detailed report if available.';
      } else {
        double totalAmount = 0.0;
        final statusCounts = <String, int>{};
        for (final tx in txs) {
          totalAmount += _readDouble(tx['amount']);
          final st = (tx['status'] ?? 'unknown').toString();
          statusCounts[st] = (statusCounts[st] ?? 0) + 1;
        }

        double sampledSalesTotal = 0.0;
        double sampledCostTotal = 0.0;
        int wholesaleLineCount = 0;
        try {
          final salesResponse = await ManagecareApiClient.instance.get(
            '/api/sales/$businessId',
            query: {'limit': limit.toString()},
          );
          final saleRowsForProfit =
              ((salesResponse['data'] as List?) ?? []).cast<Map<String, dynamic>>();

          for (final sale in saleRowsForProfit) {
            final items = (sale['items'] as List<dynamic>?) ?? [];
            final saleTotal = _readDouble(sale['total_amount']) > 0
                ? _readDouble(sale['total_amount'])
                : _readDouble(sale['final_amount']);
            sampledSalesTotal += saleTotal;

            for (final rawItem in items) {
              if (rawItem is! Map) continue;
              final item = Map<String, dynamic>.from(rawItem);
              final quantity = _saleItemQuantity(item);
              final costPerUnit = await _saleItemCostPerUnit(businessId, item);
              sampledCostTotal += costPerUnit * quantity;

              final mode = _saleItemModeLabel(item).toLowerCase();
              if (mode.contains('whole') || mode.contains('bulk') || _readDouble(item['saleUnitMultiplier']) > 1) {
                wholesaleLineCount++;
              }
            }
          }
        } catch (e) {
          print('[WhatsAppService] Failed to compute profit from sales: $e');
        }

        final grossProfit = sampledSalesTotal - sampledCostTotal;
        final grossMargin = sampledSalesTotal > 0 ? (grossProfit / sampledSalesTotal) * 100 : 0.0;

        final lines = <String>[];
        for (var i = 0; i < txs.length && i < limit; i++) {
          final tx = txs[i];
          final amt = _readDouble(tx['amount']);
          final dateStr = (tx['createdAt'] != null && tx['createdAt'].toString().isNotEmpty)
              ? parseTimestamp(tx['createdAt']).toLocal().toString().split('.').first
              : '';
          final who = (tx['cashier'] as String?)?.toString() ??
              (tx['email'] as String?)?.toString() ??
              '';
          lines.add('${i + 1}. \u20A6${amt.toStringAsFixed(2)} \u2022 ${tx['status']} \u2022 $dateStr${who.isNotEmpty ? ' \u2022 $who' : ''}');
        }

        final statusSummary = statusCounts.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');

        message = 'Daily transactions (showing up to $limit) for "$businessName"\n'
            'Total (sampled): \u20A6${totalAmount.toStringAsFixed(2)} \u2022 Transactions: ${txs.length}\n'
            'Status breakdown: $statusSummary\n'
            'Gross profit (sampled): \u20A6${grossProfit.toStringAsFixed(2)}\n'
            'Gross margin: ${grossMargin.toStringAsFixed(1)}%\n'
            'Wholesale lines: $wholesaleLineCount\n\n'
            '${lines.join('\n')}\n\n'
            'Note: Transaction IDs are omitted for privacy. A detailed report (including IDs) has been emailed to the owner.';
      }

      final url = Uri.parse('https://graph.facebook.com/v17.0/$phoneNumberId/messages');

      if (webhookUrl != null && webhookUrl.isNotEmpty) {
        try {
          final hookBody = jsonEncode({
            'businessId': businessId,
            'businessName': businessName,
            'date': DateTime.now().toIso8601String(),
            'total': txs.fold<double>(0.0, (sum, tx) => sum + _readDouble(tx['amount'])),
            'count': txs.length,
            'transactions': txs,
          });
          final hookHeaders = {'Content-Type': 'application/json'};
          final hookToken = (settings['dailyReportWebhookToken'] as String?) ??
              (AppConfig.dailyReportHookToken.isNotEmpty
                  ? AppConfig.dailyReportHookToken
                  : null);
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
      for (final rawRecipient in recipients) {
        try {
          final r = rawRecipient.replaceAll(RegExp(r'[^0-9]'), '');
          if (r.isEmpty) continue;

          final body = jsonEncode({
            'messaging_product': 'whatsapp',
            'to': r,
            'type': 'text',
            'text': {'body': message}
          });

          final resp = await http.post(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json'
            },
            body: body,
          );

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

      try {
        String? ownerEmail;
        final ownerId = data['owner_id'] ?? data['ownerId'];
        if (data['ownerEmail'] != null && data['ownerEmail'].toString().isNotEmpty) {
          ownerEmail = data['ownerEmail'].toString();
        } else if (ownerId != null) {
          final ownerRow = await Supabase.instance.client
              .from('profiles')
              .select('email')
              .eq('id', ownerId.toString())
              .maybeSingle();
          ownerEmail = ownerRow?['email'] as String?;
        }

        if (ownerEmail != null && ownerEmail.isNotEmpty) {
          final emailService = EmailService();
          final txSummary = txs
              .map((t) => '${t['transactionId']} - \u20A6${_readDouble(t['amount']).toStringAsFixed(2)} - ${t['status']} - ${t['createdAt']}')
              .join('\n');
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
          errorMessage: e.toString(),
        );
      } catch (_) {}
      return false;
    }
  }
}