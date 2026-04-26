import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/email_service.dart';
import '../services/notification_service.dart';
import '../services/notification_interface.dart';

/// Comprehensive email and notification service
/// Integrates push notifications, emails, and SMS alerts
class NotificationAndEmailService {
  final FirebaseFirestore _firestore;
  final EmailService _emailService;
  final INotificationService _notificationService;

  NotificationAndEmailService({
    FirebaseFirestore? firestore,
    EmailService? emailService,
    INotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _emailService = emailService ?? EmailService(),
        _notificationService = notificationService ?? NotificationService.instance;

  /// Send receipt email notification
  Future<Map<String, dynamic>> sendReceiptNotification({
    required String customerEmail,
    required String businessName,
    required String receiptText,
    String? customerName,
    String? businessPhone,
    String? orderId,
    bool sendPushNotification = true,
    bool sendSMS = false,
  }) async {
    try {
      final results = <String, dynamic>{
        'success': false,
        'channels': <String, bool>{},
      };

      // Send email
      try {
        final emailSuccess = await _emailService.sendReceiptEmail(
          recipient: customerEmail,
          businessName: businessName,
          receiptText: receiptText,
          customerName: customerName,
          businessPhone: businessPhone,
          orderId: orderId,
        );
        results['channels']['email'] = emailSuccess;
      } catch (e) {
        print('Email send failed: $e');
        results['channels']['email'] = false;
      }

      // Send push notification
      if (sendPushNotification) {
        try {
          final pushSuccess = await _sendPushNotification(
            title: 'Receipt Received',
            body: 'Receipt from $businessName has been sent to your email',
            payload: {
              'type': 'receipt',
              'orderId': orderId ?? '',
              'businessName': businessName,
            },
          );
          results['channels']['push'] = pushSuccess;
        } catch (e) {
          print('Push notification failed: $e');
          results['channels']['push'] = false;
        }
      }

      // Send SMS (if enabled)
      if (sendSMS) {
        try {
          final smsSuccess = await _sendSMS(
            phone: customerEmail.replaceFirst('@', '').split('.')[0],
            message:
                'Receipt from $businessName has been sent. Check your email for details.',
          );
          results['channels']['sms'] = smsSuccess;
        } catch (e) {
          print('SMS send failed: $e');
          results['channels']['sms'] = false;
        }
      }

      results['success'] = results['channels'].values.any((v) => v == true);
      results['message'] =
          'Notification sent via: ${results['channels'].entries.where((e) => e.value).map((e) => e.key).join(', ')}';

      return results;
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to send notification: $e',
      };
    }
  }

  /// Send order confirmation notification
  Future<bool> sendOrderConfirmation({
    required String customerEmail,
    required String businessName,
    required String orderId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? businessId,
  }) async {
    try {
      // Enrich items names using business inventory if businessId provided and name missing
    final enrichedItems = <Map<String, String>>[];
    for (final i in items) {
      var name = (i['name'] as String?) ?? (i['productName'] as String?) ?? '';
      final productId = (i['productId'] as String?) ?? (i['id'] as String?);
      if (name.isEmpty && productId != null && businessId != null && businessId.isNotEmpty) {
        try {
          final invDoc = await _firestore.collection('businesses').doc(businessId).collection('inventory').doc(productId).get();
          if (invDoc.exists) {
            final invData = invDoc.data() ?? {};
            name = (invData['name'] as String?) ?? name;
          }
        } catch (e) {
          print('[NotificationAndEmailService] inventory lookup failed: $e');
        }
      }

      enrichedItems.add({
        'name': name,
        'quantity': (i['quantity']?.toString() ?? (i['qty']?.toString() ?? '1')),
        'price': (i['price'] ?? i['unitPrice'] ?? 0).toString(),
      });
    }

    final data = <String, dynamic>{
        'businessName': businessName,
        'order_id': orderId,
        'total': totalAmount.toStringAsFixed(2),
        'itemsCount': enrichedItems.length,
        'items': enrichedItems,
        'customerName': customerName ?? 'Valued Customer',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Order templates are gated as Pro; include plan flag
      return await _emailService.sendOrderSuccessAlert(
        customerEmail,
        data,
      );
    } catch (e) {
      print('Order confirmation failed: $e');
      return false;
    }
  }

  /// Send payment reminder notification
  Future<bool> sendPaymentReminder({
    required String customerEmail,
    required String businessName,
    required double dueAmount,
    required String dueDate,
    String? orderId,
  }) async {
    try {
      final data = {
        'businessName': businessName,
        'dueAmount': dueAmount.toString(),
        'dueDate': dueDate,
        'orderId': orderId ?? '',
      };

      return await _emailService.sendSubscriptionPaymentAlert(
        customerEmail,
        data,
      );
    } catch (e) {
      print('Payment reminder failed: $e');
      return false;
    }
  }

  /// Send low stock alert
  Future<bool> sendLowStockAlert({
    required String ownerEmail,
    required String businessName,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final itemList = items
          .map((item) => '${item['name']} (${item['quantity']} remaining)')
          .join(', ');

      final data = {
        'businessName': businessName,
        'items': itemList,
        'timestamp': DateTime.now().toString(),
      };

      return await _emailService.sendLowStockAlert(ownerEmail, data);
    } catch (e) {
      print('Low stock alert failed: $e');
      return false;
    }
  }

  /// Send expiry alert
  Future<bool> sendExpiryAlert({
    required String ownerEmail,
    required String businessName,
    required List<Map<String, dynamic>> expiredItems,
  }) async {
    try {
      final itemList = expiredItems
          .map((item) => '${item['name']} (Expired: ${item['expiryDate']})')
          .join(', ');

      final data = {
        'businessName': businessName,
        'items': itemList,
        'timestamp': DateTime.now().toString(),
      };

      return await _emailService.sendTemplateEmail(
        'expiry',
        ownerEmail,
        data,
        subject: 'Expiry Alert - $businessName',
      );
    } catch (e) {
      print('Expiry alert failed: $e');
      return false;
    }
  }

  /// Send sales notification email to business owner (delegates to WebEmailReceiptService)
  Future<bool> sendSalesNotification({
    required String ownerEmail,
    required String businessName,
    required String customerName,
    required String customerEmail,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String receiptNumber,
    String? businessId, // optional - used to enrich item names from inventory
    String? customerPhone,
    String? cashierName,
    String? cashierEmail,
    String? storeName,
    String? cartLabel,
    double? subtotal,
    double? tax,
    double? discount,
    List<Map<String, dynamic>>? paymentBreakdown,
    DateTime? saleTime,
  }) async {
    try {
      // Enrich items names using business inventory if businessId provided and name missing
      final enrichedItems = <Map<String, dynamic>>[];
      for (final i in items) {
        var name = (i['name'] as String?) ?? (i['productName'] as String?) ?? '';
        final productId = (i['productId'] as String?) ?? (i['id'] as String?);
        if (name.isEmpty && productId != null && businessId != null && businessId.isNotEmpty) {
          try {
            final invDoc = await _firestore.collection('businesses').doc(businessId).collection('inventory').doc(productId).get();
            if (invDoc.exists) {
              final invData = invDoc.data() ?? {};
              name = (invData['name'] as String?) ?? name;
            }
          } catch (e) {
            print('[NotificationAndEmailService] inventory lookup failed: $e');
          }
        }

        enrichedItems.add({
          'name': name,
          'quantity': i['quantity'] ?? i['qty'] ?? 1,
          'price': i['price'] ?? i['unitPrice'] ?? 0,
          'total': i['total'],
          'unit': i['unit'],
          'saleUnit': i['saleUnit'],
          'pricingMode': i['pricingMode'],
          'productId': productId,
        });
      }

      final data = <String, dynamic>{
        'businessName': businessName,
        'saleReference': receiptNumber,
        'saleTime': (saleTime ?? DateTime.now()).toIso8601String(),
        'total': totalAmount,
        'subtotal': subtotal ?? totalAmount,
        'tax': tax ?? 0.0,
        'discount': discount ?? 0.0,
        'itemsCount': enrichedItems.length,
        'items': enrichedItems,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'cashierName': cashierName,
        'cashierEmail': cashierEmail,
        'storeName': storeName,
        'cartLabel': cartLabel,
        'paymentMethod': paymentMethod,
        'paymentBreakdown': paymentBreakdown ?? <Map<String, dynamic>>[],
      };

      return await _emailService.sendOwnerSalesAlertEmail(
        ownerEmail,
        data,
      );
    } catch (e) {
      print('sendSalesNotification failed: $e');
      return false;
    }
  }

  Future<bool> sendProcurementNotification({
    required String ownerEmail,
    required String businessName,
    required String procurementId,
    required List<Map<String, dynamic>> items,
    required double totalCost,
    required double totalQuantity,
    required int itemsCount,
    required String createdByName,
    String? createdByEmail,
    String? supplierName,
    String? invoiceRef,
    String? storeName,
    String? referenceImageUrl,
    DateTime? createdAt,
  }) async {
    try {
      final data = <String, dynamic>{
        'businessName': businessName,
        'procurementId': procurementId,
        'items': items,
        'itemsCount': itemsCount,
        'totalCost': totalCost,
        'totalQuantity': totalQuantity,
        'createdByName': createdByName,
        'createdByEmail': createdByEmail,
        'supplierName': supplierName,
        'invoiceRef': invoiceRef,
        'storeName': storeName,
        'referenceImageUrl': referenceImageUrl,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

      return await _emailService.sendProcurementAlertEmail(
        ownerEmail,
        data,
      );
    } catch (e) {
      print('sendProcurementNotification failed: $e');
      return false;
    }
  }

  /// Send push notification
  Future<bool> _sendPushNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _notificationService.sendNotification(
        title,
        body,
        id: payload.hashCode,
      );
      return true;
    } catch (e) {
      print('Push notification error: $e');
      return false;
    }
  }

  /// Send SMS notification (stub - requires Twilio or similar service)
  Future<bool> _sendSMS({
    required String phone,
    required String message,
  }) async {
    // This would integrate with a service like Twilio
    // For now, just return false
    print('SMS would be sent to: $phone - $message');
    return false;
  }

  /// Log notification event to Firestore
  Future<void> logNotificationEvent({
    required String businessId,
    required String type,
    required String channel,
    required String recipient,
    required bool success,
    String? orderId,
    String? errorMessage,
  }) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('notificationLogs')
          .add({
        'type': type,
        'channel': channel,
        'recipient': recipient,
        'success': success,
        'orderId': orderId,
        'error': errorMessage,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to log notification: $e');
    }
  }

  /// Get notification preferences for user
  Future<Map<String, dynamic>?> getUserNotificationPreferences(
      String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['notificationPreferences'];
    } catch (e) {
      print('Failed to get notification preferences: $e');
      return null;
    }
  }

  /// Update notification preferences
  Future<bool> updateNotificationPreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationPreferences': preferences,
        'preferencesUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Failed to update preferences: $e');
      return false;
    }
  }

  /// Send bulk notifications
  Future<Map<String, dynamic>> sendBulkNotifications({
    required List<Map<String, dynamic>> recipients,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      int successCount = 0;
      int failureCount = 0;
      final errors = <String>[];

      for (final recipient in recipients) {
        try {
          switch (type) {
            case 'payment_reminder':
              final success = await sendPaymentReminder(
                customerEmail: recipient['email'],
                businessName: recipient['businessName'] ?? '',
                dueAmount: recipient['dueAmount'] ?? 0.0,
                dueDate: recipient['dueDate'] ?? '',
                orderId: recipient['orderId'],
              );
              if (success) {
                successCount++;
              } else {
                failureCount++;
              }
              break;

            case 'low_stock':
              final success = await sendLowStockAlert(
                ownerEmail: recipient['email'],
                businessName: recipient['businessName'] ?? '',
                items: recipient['items'] ?? [],
              );
              if (success) {
                successCount++;
              } else {
                failureCount++;
              }
              break;

            case 'expiry':
              final success = await sendExpiryAlert(
                ownerEmail: recipient['email'],
                businessName: recipient['businessName'] ?? '',
                expiredItems: recipient['expiredItems'] ?? [],
              );
              if (success) {
                successCount++;
              } else {
                failureCount++;
              }
              break;

            default:
              failureCount++;
              errors.add('Unknown notification type: $type');
          }
        } catch (e) {
          failureCount++;
          errors.add(e.toString());
        }
      }

      return {
        'success': failureCount == 0,
        'successCount': successCount,
        'failureCount': failureCount,
        'totalRecipients': recipients.length,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Bulk notification failed: $e',
      };
    }
  }
}

