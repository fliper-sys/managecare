import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class InventoryExpiryAlertSummary {
  final int total;
  final int expired;
  final int dueToday;
  final int dueSoon;
  final int healthy;

  const InventoryExpiryAlertSummary({
    required this.total,
    required this.expired,
    required this.dueToday,
    required this.dueSoon,
    required this.healthy,
  });

  bool get hasAlerts => total > 0;
}

class InventoryExpiryAlert {
  final String productId;
  final String productName;
  final String category;
  final String unit;
  final double quantity;
  final String? storeId;
  final String? batchId;
  final String? batchLabel;
  final DateTime expiryDate;
  final bool isBatchTracked;
  final String source;

  const InventoryExpiryAlert({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.expiryDate,
    required this.isBatchTracked,
    required this.source,
    this.storeId,
    this.batchId,
    this.batchLabel,
  });

  DateTime get normalizedExpiryDate =>
      DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

  int get daysUntilExpiry =>
      normalizedExpiryDate.difference(_today()).inDays;

  bool get isExpired => daysUntilExpiry < 0;
  bool get expiresToday => daysUntilExpiry == 0;
  bool get expiresWithin30Days => daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  bool get expiresWithin7Days => daysUntilExpiry >= 0 && daysUntilExpiry <= 7;

  String get severity {
    if (isExpired) return 'expired';
    if (expiresToday) return 'today';
    if (expiresWithin7Days) return 'critical';
    if (expiresWithin30Days) return 'warning';
    return 'healthy';
  }

  String get uniqueKey =>
      '$productId:${batchId ?? 'inventory'}:${normalizedExpiryDate.toIso8601String()}';

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class InventoryExpiryService {
  InventoryExpiryService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<InventoryExpiryAlert>> fetchAlerts(
    String businessId, {
    int warningDays = 30,
  }) async {
    if (businessId.trim().isEmpty) return const [];

    final inventorySnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('inventory')
        .get();

    final alerts = <InventoryExpiryAlert>[];
    final seenKeys = <String>{};

    for (final doc in inventorySnapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final category = (data['category'] ?? 'Uncategorized').toString();
      final unit = (data['unit'] ?? 'pcs').toString();
      final storeId = data['storeId']?.toString();
      final trackExpiry = data['trackExpiry'] == true;
      final productExpiry = _parseDate(data['expiryDate']);

      if (trackExpiry && productExpiry != null) {
        final alert = InventoryExpiryAlert(
          productId: doc.id,
          productName: name,
          category: category,
          unit: unit,
          quantity: _toDouble(data['quantity']),
          storeId: storeId,
          expiryDate: productExpiry,
          isBatchTracked: false,
          source: 'inventory',
          batchLabel: (data['batchLabel'] as String?)?.trim(),
        );
        if (_shouldIncludeAlert(alert, warningDays) &&
            seenKeys.add(alert.uniqueKey)) {
          alerts.add(alert);
        }
      }

      final batches = await doc.reference.collection('batches').get();
      for (final batchDoc in batches.docs) {
        final batchData = batchDoc.data();
        final expiryDate = _parseDate(batchData['expiryDate']);
        if (expiryDate == null) continue;

        final remainingQuantity = _toDouble(
          batchData['remainingQuantity'] ?? batchData['quantity'],
        );
        if (remainingQuantity <= 0) continue;

        final alert = InventoryExpiryAlert(
          productId: doc.id,
          productName: name,
          category: category,
          unit: (batchData['unit'] ?? unit).toString(),
          quantity: remainingQuantity,
          storeId: storeId,
          batchId: batchDoc.id,
          batchLabel: (batchData['batchLabel'] ?? '').toString().trim(),
          expiryDate: expiryDate,
          isBatchTracked: true,
          source: 'batch',
        );
        if (_shouldIncludeAlert(alert, warningDays) &&
            seenKeys.add(alert.uniqueKey)) {
          alerts.add(alert);
        }
      }
    }

    alerts.sort((a, b) {
      final severityCompare =
          _severityRank(a.severity).compareTo(_severityRank(b.severity));
      if (severityCompare != 0) return severityCompare;
      final dateCompare = a.expiryDate.compareTo(b.expiryDate);
      if (dateCompare != 0) return dateCompare;
      return a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
    });

    return alerts;
  }

  InventoryExpiryAlertSummary summarize(List<InventoryExpiryAlert> alerts) {
    var expired = 0;
    var dueToday = 0;
    var dueSoon = 0;
    var healthy = 0;

    for (final alert in alerts) {
      switch (alert.severity) {
        case 'expired':
          expired++;
          break;
        case 'today':
          dueToday++;
          break;
        case 'critical':
        case 'warning':
          dueSoon++;
          break;
        default:
          healthy++;
      }
    }

    return InventoryExpiryAlertSummary(
      total: alerts.length,
      expired: expired,
      dueToday: dueToday,
      dueSoon: dueSoon,
      healthy: healthy,
    );
  }

  Future<void> syncExpiryNotifications({
    required String businessId,
    required String ownerUserId,
    String? businessName,
    int warningDays = 30,
  }) async {
    if (businessId.trim().isEmpty || ownerUserId.trim().isEmpty) return;

    final alerts = await fetchAlerts(businessId, warningDays: warningDays);
    final summary = summarize(alerts);
    if (!summary.hasAlerts) return;

    final today = DateTime.now();
    final dayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final summaryKey =
        '$dayKey:${summary.expired}:${summary.dueToday}:${summary.dueSoon}';

    final existing = await _firestore
        .collection('users')
        .doc(ownerUserId)
        .collection('notifications')
        .where('type', isEqualTo: 'inventory_expiry_summary')
        .where('summaryKey', isEqualTo: summaryKey)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    final title = summary.expired > 0
        ? 'Expiry Alert'
        : summary.dueToday > 0
            ? 'Expiry Due Today'
            : 'Expiry Warning';
    final body = _buildSummaryBody(summary);

    try {
      await NotificationService.instance.sendNotification(title, body);
    } catch (e) {
      debugPrint('[InventoryExpiryService] Local notification failed: $e');
    }

    await _firestore
        .collection('users')
        .doc(ownerUserId)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': 'inventory_expiry_summary',
      'summaryKey': summaryKey,
      'businessId': businessId,
      'businessName': businessName,
      'channel': 'inventory_expiry',
      'isRead': false,
      'delivered': true,
      'createdAt': FieldValue.serverTimestamp(),
      'data': {
        'type': 'inventory_expiry_summary',
        'businessId': businessId,
        'expiredCount': summary.expired,
        'dueTodayCount': summary.dueToday,
        'dueSoonCount': summary.dueSoon,
        'totalCount': summary.total,
        'warningDays': warningDays,
      },
    });

  }

  bool _shouldIncludeAlert(InventoryExpiryAlert alert, int warningDays) {
    return alert.isExpired ||
        alert.expiresToday ||
        (alert.daysUntilExpiry >= 0 && alert.daysUntilExpiry <= warningDays);
  }

  int _severityRank(String severity) {
    switch (severity) {
      case 'expired':
        return 0;
      case 'today':
        return 1;
      case 'critical':
        return 2;
      case 'warning':
        return 3;
      default:
        return 4;
    }
  }

  String _buildSummaryBody(InventoryExpiryAlertSummary summary) {
    final parts = <String>[];
    if (summary.expired > 0) parts.add('${summary.expired} expired');
    if (summary.dueToday > 0) parts.add('${summary.dueToday} due today');
    if (summary.dueSoon > 0) parts.add('${summary.dueSoon} due soon');
    return parts.join(' | ');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
