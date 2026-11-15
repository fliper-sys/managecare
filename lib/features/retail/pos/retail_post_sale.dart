import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/email_service.dart';
import '../../../services/notification_and_email_service.dart';
import '../../../services/web_email_receipt_service.dart';

/// Everything the old retail POS does after a sale is recorded, apart from
/// the receipt options dialog (that is a button on the v2 receipt).
///
/// Order and conditions match `sales_screen.dart`: offline sales refresh the
/// pending-sync badge and lower stock in memory; online sales email the
/// customer a receipt (when they have an email), alert the owner, log the
/// alert, and send the order-success email on plans with `email_receipts`.
/// Every step is best effort: a failure here never undoes the sale.
Future<void> runRetailPostSale(
  BuildContext context, {
  required Map<String, dynamic> sale,
  required bool savedOffline,
  required int itemCount,
  required double totalBefore,
  required String cartLabel,
  String? customerPhone,
}) async {
  final retail = context.read<RetailProvider>();
  final business = context.read<BusinessProvider>();
  final auth = context.read<AuthProvider>();
  final sync = context.read<SyncProvider>();
  final connected = context.read<ConnectivityProvider>().isConnected;
  final items = (sale['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  if (savedOffline) {
    sync.checkPendingItems();
    // Lower stock in memory so the catalogue is right until the sync runs.
    for (final item in items) {
      final id = item['productId'] as String?;
      final sold = (item['inventoryQuantity'] as num?)?.toDouble() ?? (item['quantity'] as num?)?.toDouble() ?? 0;
      if (id == null || sold <= 0) continue;
      for (final p in retail.products) {
        if (p.id == id) {
          final next = p.stock - sold;
          p.stock = next > 0 ? next : 0;
          break;
        }
      }
    }
    return;
  }

  final biz = business.currentBusiness;
  final customerEmail = (sale['customerEmail'] as String?) ?? '';
  final customerName = sale['customerName'] as String?;
  final pm = sale['paymentMethod'] as String? ?? '';
  final breakdown = (sale['paymentBreakdown'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  if (biz != null && connected) {
    try {
      var receiptSent = false;
      if (customerEmail.isNotEmpty) {
        receiptSent = await WebEmailReceiptService().sendReceiptEmail(
          recipientEmail: customerEmail,
          receiptNumber: sale['id'].toString(),
          businessName: biz.name,
          customerName: customerName ?? 'Valued Customer',
          totalAmount: sale['total'] as double,
          subtotal: sale['subtotal'] as double,
          tax: sale['tax'] as double,
          items: [
            for (final i in items) {'name': i['name'], 'quantity': i['quantity'], 'price': i['price']},
          ],
          paymentMethod: pm,
          paymentBreakdown: breakdown,
          businessLogo: biz.logoUrl,
          businessContact: biz.phone,
        );
      }

      var ownerEmail = '';
      if (biz.ownerId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(biz.ownerId).get();
          ownerEmail = ((doc.data() ?? const <String, dynamic>{})['email'] as String? ?? '').trim();
        } catch (e) {
          debugPrint('[RetailPostSale] owner email lookup failed: $e');
        }
      }
      if (ownerEmail.isEmpty) ownerEmail = (biz.email ?? '').trim();
      if (ownerEmail.isEmpty && auth.currentUser?.id == biz.ownerId) {
        ownerEmail = (auth.currentUser?.email ?? '').trim();
      }

      var ownerSent = false;
      if (ownerEmail.isNotEmpty) {
        final notif = NotificationAndEmailService();
        ownerSent = await notif.sendSalesNotification(
          ownerEmail: ownerEmail,
          businessName: biz.name,
          customerName: customerName ?? 'Walk-in Customer',
          customerEmail: customerEmail,
          customerPhone: customerPhone,
          totalAmount: sale['total'] as double,
          items: items,
          paymentMethod: pm,
          receiptNumber: (sale['referenceId'] ?? sale['id']).toString(),
          businessId: biz.id,
          cashierName: auth.currentUser?.fullName,
          cashierEmail: auth.currentUser?.email,
          storeName: sale['storeName']?.toString(),
          cartLabel: sale['cartLabel']?.toString(),
          subtotal: sale['subtotal'] as double,
          tax: sale['tax'] as double,
          discount: sale['discount'] as double,
          paymentBreakdown: breakdown,
          saleTime: sale['createdAt'] as DateTime?,
        );
        try {
          await notif.logNotificationEvent(
            businessId: biz.id,
            type: 'sale',
            channel: 'email',
            recipient: ownerEmail,
            success: ownerSent,
            orderId: sale['id'].toString(),
          );
        } catch (e) {
          debugPrint('[RetailPostSale] notification log failed: $e');
        }
      }

      if (context.mounted && (receiptSent || ownerSent)) {
        final text = receiptSent && ownerSent
            ? 'Receipt and owner notification emails sent'
            : ownerSent
                ? 'Owner sale alert email sent'
                : 'Customer receipt email sent';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sale completed but emails failed: $e')));
      }
    }
  }

  try {
    final userEmail = auth.currentUser?.email;
    if (business.hasFeatureAccess('email_receipts') && userEmail != null && userEmail.isNotEmpty) {
      await EmailService().sendOrderSuccessAlert(userEmail, {
        'order_type': 'retail_sale',
        'itemsCount': itemCount.toString(),
        'total': totalBefore.toStringAsFixed(2),
        'cartLabel': cartLabel,
      });
    }
  } catch (_) {
    // Same as the old POS: this alert is optional.
  }
}
