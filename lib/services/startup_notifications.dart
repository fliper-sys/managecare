import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/business_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/reports_provider.dart';
import '../providers/pharmacy_provider.dart';
import '../providers/inventory_alerts_provider.dart';
import 'notification_service.dart';


class StartupNotifications {
  /// Send a set of helpful notifications when the app starts or a user logs in.
  /// This will attempt to wait briefly for `BusinessProvider.currentBusiness`
  /// to become available (up to [timeoutMs]) before giving up.
  static Future<void> run(BuildContext context, {int timeoutMs = 5000}) async {
    try {
      final start = DateTime.now();

      // Wait until business is available or timeout
      BusinessProvider businessProvider = context.read<BusinessProvider>();
      while (businessProvider.currentBusiness == null &&
          DateTime.now().difference(start).inMilliseconds < timeoutMs) {
        await Future.delayed(const Duration(milliseconds: 300));
        businessProvider = context.read<BusinessProvider>();
      }

      final business = businessProvider.currentBusiness;
      if (business == null) return; // nothing to do

      final notifPref = context.read<NotificationProvider>();
      final reports = context.read<ReportsProvider>();
      final inventoryProvider = context.read<InventoryAlertsProvider>();
      final pharmacyProvider = context.read<PharmacyProvider>();

      // --- Recent sales (2 most recent) ---
      try {
        if (notifPref.shouldShowNotification('sales')) {
          final recent = await reports.fetchSalesList(
              businessId: business.id, limit: 2);
          if (recent.isNotEmpty) {
            final parts = recent.map((r) {
              final d = r['data'] as Map<String, dynamic>;
              final cust = (d['customerName'] ?? d['customerDisplayName'] ?? d['customer'] ?? 'Customer').toString();
              final amt = ((d['finalAmount'] ?? d['totalAmount'] ?? d['total'] ?? 0) as num).toDouble();
              final pm = (d['paymentMethod'] ?? d['payment'] ?? 'unknown').toString();
              return '$cust - ${amt.toStringAsFixed(2)} via $pm';
            }).join(' • ');

            final title = recent.length == 1 ? 'Recent Sale' : '${recent.length} Recent Sales';
            final body = parts;

            await _sendOrScheduleNotification(business.id, title, body, notifPref, 'startup_sales');
          }
        }
      } catch (e) {
        // ignore errors but log
        await _logNotification(business.id, {
          'type': 'startup_sales',
          'channel': 'local',
          'recipient': 'local_device',
          'success': false,
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // --- Inventory / Low stock alerts ---
      try {
        if (notifPref.shouldShowNotification('inventory')) {
          inventoryProvider.setBusinessId(business.id);
          await inventoryProvider.loadAlerts();

          final active = inventoryProvider.activeAlerts;
          if (active.isNotEmpty) {
            final count = active.length;
            final title = count == 1 ? 'Low Stock Alert' : 'Low Stock Alerts';
            final body = '${count} items need attention';

            await _sendOrScheduleNotification(business.id, title, body, notifPref, 'startup_inventory');
          }
        }
      } catch (e) {
        await _logNotification(business.id, {
          'type': 'startup_inventory',
          'channel': 'local',
          'recipient': 'local_device',
          'success': false,
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // --- Expiry warnings (pharmacy) ---
      try {
        if (notifPref.shouldShowNotification('inventory')) {
          final expiring = pharmacyProvider.getExpiringDrugs();
          if (expiring.isNotEmpty) {
            final count = expiring.length;
            final title = count == 1 ? 'Expiring Soon' : 'Expiring Items';
            final body = '${count} item(s) expiring soon';

            await _sendOrScheduleNotification(business.id, title, body, notifPref, 'startup_expiry');
          }
        }
      } catch (e) {
        await _logNotification(business.id, {
          'type': 'startup_expiry',
          'channel': 'local',
          'recipient': 'local_device',
          'success': false,
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Top-level catch to avoid crashing the app
      debugPrint('[StartupNotifications] failed: $e');
    }
  }

  static Future<void> _sendOrScheduleNotification(String businessId, String title, String body, NotificationProvider pref, String type) async {
    try {
      final freq = pref.frequency;
      if (freq == NotificationFrequency.realTime) {
        await NotificationService.instance.sendNotification(title, body);
        await _logNotification(businessId, {
          'type': type,
          'channel': 'local',
          'recipient': 'local_device',
          'success': true,
          'message': body,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Schedule for next boundary according to frequency
      DateTime now = DateTime.now();
      DateTime at;
      if (freq == NotificationFrequency.hourly) {
        at = DateTime(now.year, now.month, now.day, now.hour).add(const Duration(hours: 1));
      } else {
        // daily
        final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        at = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9); // 9:00 AM next day
      }

      final id = businessId.hashCode ^ title.hashCode;
      await NotificationService.instance.scheduleNotificationAt(id: id, title: title, body: body, at: at);

      await _logNotification(businessId, {
        'type': type,
        'channel': 'local',
        'recipient': 'local_device',
        'success': true,
        'message': body,
        'scheduledAt': at.toUtc().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'scheduled',
      });
    } catch (e) {
      await _logNotification(businessId, {
        'type': type,
        'channel': 'local',
        'recipient': 'local_device',
        'success': false,
        'error': e.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> _logNotification(String businessId, Map<String, dynamic> doc) async {
    try {
      final fs = FirebaseFirestore.instance;
      await fs.collection('businesses').doc(businessId).collection('notificationLogs').add(doc);
    } catch (e) {
      debugPrint('[StartupNotifications] failed to log notification: $e');
    }
  }
}
