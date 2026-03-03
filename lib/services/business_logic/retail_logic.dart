import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Retail-specific business logic
class RetailBusinessLogic {
  final FirebaseFirestore _firestore;

  RetailBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Manage wholesale orders
  Future<List<WholesaleOrder>> getWholesaleOrders(
    String businessId,
    String? status,
  ) async {
    try {
      Query query = _firestore
          .collection('retail')
          .doc(businessId)
          .collection('wholesaleOrders');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snap = await query.orderBy('date', descending: true).get();

      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return WholesaleOrder.fromMap({...data, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Error getting wholesale orders: $e');
      return [];
    }
  }

  /// Get supplier performance
  Future<List<SupplierPerformance>> getSupplierPerformance(
    String businessId,
  ) async {
    try {
      final snap = await _firestore
          .collection('retail')
          .doc(businessId)
          .collection('suppliers')
          .get();

      final performance = <SupplierPerformance>[];

      for (var doc in snap.docs) {
        final data = doc.data();
        final supplierId = doc.id;

        // Get supplier metrics
        final ordersSnap = await _firestore
            .collection('retail')
            .doc(businessId)
            .collection('wholesaleOrders')
            .where('supplierId', isEqualTo: supplierId)
            .get();

        int totalOrders = ordersSnap.docs.length;
        int onTimeDeliveries = ordersSnap.docs
            .where((d) => (d.data()['deliveredOnTime'] as bool?) ?? false)
            .length;
        double onTimePercentage =
            totalOrders > 0 ? (onTimeDeliveries / totalOrders * 100) : 0;

        performance.add(SupplierPerformance(
          supplierId: supplierId,
          supplierName: data['name'] ?? 'Unknown',
          totalOrders: totalOrders,
          onTimePercentage: onTimePercentage,
          rating: (data['rating'] as num?)?.toDouble() ?? 0,
          totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0,
        ));
      }

      return performance
        ..sort((a, b) => b.onTimePercentage.compareTo(a.onTimePercentage));
    } catch (e) {
      print('Error getting supplier performance: $e');
      return [];
    }
  }

  /// Calculate inventory turnover
  Future<InventoryTurnover> calculateInventoryTurnover(
    String businessId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Get sales data
      final salesSnap = await _firestore
          .collection('retail')
          .doc(businessId)
          .collection('sales')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      double totalUnitsSold = 0;
      double totalRevenue = 0;

      for (var doc in salesSnap.docs) {
        final data = doc.data();
        totalUnitsSold += (data['units'] as num?)?.toDouble() ?? 0;
        totalRevenue += (data['amount'] as num?)?.toDouble() ?? 0;
      }

      // Get average inventory value
      final inventorySnap = await _firestore
          .collection('retail')
          .doc(businessId)
          .collection('inventory')
          .get();

      double totalInventoryValue = 0;
      for (var doc in inventorySnap.docs) {
        final data = doc.data();
        final stock = (data['stock'] as num?)?.toInt() ?? 0;
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        totalInventoryValue += (stock * price).toDouble();
      }

      final avgInventoryValue = totalInventoryValue;
      final turnoverRatio =
          avgInventoryValue > 0 ? totalRevenue / avgInventoryValue : 0;
      final daysInventoryOutstanding =
          avgInventoryValue > 0 ? (365 * avgInventoryValue) / totalRevenue : 0;

      return InventoryTurnover(
        periodStart: startDate,
        periodEnd: endDate,
        totalUnitsSold: totalUnitsSold.toInt(),
        totalRevenue: totalRevenue,
        avgInventoryValue: avgInventoryValue,
        turnoverRatio: turnoverRatio as double,
        daysInventoryOutstanding: daysInventoryOutstanding.toInt(),
      );
    } catch (e) {
      print('Error calculating inventory turnover: $e');
      return InventoryTurnover(
        periodStart: startDate,
        periodEnd: endDate,
        totalUnitsSold: 0,
        totalRevenue: 0,
        avgInventoryValue: 0,
        turnoverRatio: 0,
        daysInventoryOutstanding: 0,
      );
    }
  }

  /// Analyze store traffic patterns
  Future<StoreTrafficAnalysis> analyzeStoreTraffic(
    String businessId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final transactionsSnap = await _firestore
          .collection('retail')
          .doc(businessId)
          .collection('sales')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      final hourlyTraffic = <int, int>{};
      final daylyTraffic = <String, int>{};

      for (var doc in transactionsSnap.docs) {
        final data = doc.data();
        final date = parseTimestamp(data['date']);
        if (true) {
          final hour = date.hour;
          final day = _getDayName(date.weekday);

          hourlyTraffic[hour] = (hourlyTraffic[hour] ?? 0) + 1;
          daylyTraffic[day] = (daylyTraffic[day] ?? 0) + 1;
        }
      }

      final peakHour =
          hourlyTraffic.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final peakDay =
          daylyTraffic.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      return StoreTrafficAnalysis(
        peakHour: peakHour,
        peakDay: peakDay,
        totalTransactions: transactionsSnap.docs.length,
        hourlyBreakdown: hourlyTraffic,
        dailyBreakdown: daylyTraffic,
      );
    } catch (e) {
      print('Error analyzing store traffic: $e');
      return StoreTrafficAnalysis(
        peakHour: 12,
        peakDay: 'Monday',
        totalTransactions: 0,
        hourlyBreakdown: {},
        dailyBreakdown: {},
      );
    }
  }

  String _getDayName(int weekday) {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }
}

class WholesaleOrder {
  final String id;
  final String supplierId;
  final double totalAmount;
  final String status; // pending, confirmed, shipped, delivered
  final DateTime date;
  final DateTime? deliveryDate;
  final int itemCount;

  WholesaleOrder({
    required this.id,
    required this.supplierId,
    required this.totalAmount,
    required this.status,
    required this.date,
    this.deliveryDate,
    required this.itemCount,
  });

  factory WholesaleOrder.fromMap(Map<String, dynamic> map) {
      return WholesaleOrder(
      id: map['id'] ?? '',
      supplierId: map['supplierId'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      status: map['status'] ?? 'pending',
        date: parseTimestamp(map['date']),
        deliveryDate: map['deliveryDate'] != null ? parseTimestamp(map['deliveryDate']) : null,
      itemCount: map['itemCount'] ?? 0,
    );
  }
}

class SupplierPerformance {
  final String supplierId;
  final String supplierName;
  final int totalOrders;
  final double onTimePercentage;
  final double rating;
  final double totalSpent;

  SupplierPerformance({
    required this.supplierId,
    required this.supplierName,
    required this.totalOrders,
    required this.onTimePercentage,
    required this.rating,
    required this.totalSpent,
  });
}

class InventoryTurnover {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalUnitsSold;
  final double totalRevenue;
  final double avgInventoryValue;
  final double turnoverRatio;
  final int daysInventoryOutstanding;

  InventoryTurnover({
    required this.periodStart,
    required this.periodEnd,
    required this.totalUnitsSold,
    required this.totalRevenue,
    required this.avgInventoryValue,
    required this.turnoverRatio,
    required this.daysInventoryOutstanding,
  });
}

class StoreTrafficAnalysis {
  final int peakHour;
  final String peakDay;
  final int totalTransactions;
  final Map<int, int> hourlyBreakdown;
  final Map<String, int> dailyBreakdown;

  StoreTrafficAnalysis({
    required this.peakHour,
    required this.peakDay,
    required this.totalTransactions,
    required this.hourlyBreakdown,
    required this.dailyBreakdown,
  });
}

