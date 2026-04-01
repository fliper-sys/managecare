import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/analytics_repository.dart';

/// Firebase implementation of analytics repository
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  // Helper to get a DateTime from a sale doc with flexible date fields
  DateTime _getSaleDate(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return DateTime.now();
      if (data['createdAt'] is Timestamp)
        return (data['createdAt'] as Timestamp).toDate();
      if (data['timestamp'] is int)
        return DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int);
      if (data['createdAt'] is DateTime) return data['createdAt'] as DateTime;
      if (data['createdAt'] is String)
        return DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
      return DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Future<dynamic> getSalesAnalytics(String businessId,
      {required DateTime startDate, required DateTime endDate}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalSales = 0;
      int totalTransactions = 0;

      var salesDocs = snapshot.docs;
      // Fallback: if createdAt isn't used, try numeric `timestamp` field
      if (salesDocs.isEmpty) {
        final tsSnapshot = await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .where('timestamp',
                isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
            .where('timestamp',
                isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
            .get();
        salesDocs = tsSnapshot.docs;
      }

      for (var doc in salesDocs) {
        // Use safe data access to prevent "field does not exist" errors
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final amount = (data['totalAmount'] as num?) ??
            (data['total'] as num?) ??
            (data['amount'] as num?) ??
            (data['finalAmount'] as num?) ??
            0;
        totalSales += (amount).toDouble();
        totalTransactions++;
      }

      return {
        'totalSales': totalSales,
        'totalTransactions': totalTransactions,
        'averageTransactionValue':
            totalTransactions > 0 ? totalSales / totalTransactions : 0,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getInventoryAnalytics(String businessId) async {
    try {
      final snapshot =
          await _firestore.collection('businesses/$businessId/inventory').get();

      int totalItems = snapshot.docs.length;
      int lowStockItems = 0;
      int expiredItems = 0;

      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final quantity = (doc['quantity'] as num?)?.toInt() ?? 0;
        final expiryDate = doc['expiryDate'] as DateTime?;

        if (quantity < 10) lowStockItems++;
        if (expiryDate != null && expiryDate.isBefore(now)) expiredItems++;
      }

      return {
        'totalItems': totalItems,
        'lowStockItems': lowStockItems,
        'expiredItems': expiredItems,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getCustomerAnalytics(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('businessId', isEqualTo: businessId)
          .get();

      return {
        'totalCustomers': snapshot.docs.length,
        'activeCustomers':
            snapshot.docs.where((doc) => doc['isActive'] == true).length,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getRevenueReport(String businessId,
      {required DateTime startDate, required DateTime endDate}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('sales')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalRevenue = 0;
      Map<String, double> revenueByDay = {};

      var salesDocs = snapshot.docs;
      if (salesDocs.isEmpty) {
        final tsSnapshot = await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .where('timestamp',
                isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
            .where('timestamp',
                isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
            .get();
        salesDocs = tsSnapshot.docs;
      }

      for (var doc in salesDocs) {
        // Use safe data access to prevent "field does not exist" errors
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final amount = (data['totalAmount'] as num?) ??
            (data['total'] as num?) ??
            (data['amount'] as num?) ??
            (data['finalAmount'] as num?) ??
            0;
        final date = _getSaleDate(doc);
        final dateKey = '${date.year}-${date.month}-${date.day}';

        totalRevenue += (amount).toDouble();
        revenueByDay[dateKey] = (revenueByDay[dateKey] ?? 0) + (amount).toDouble();
      }

      return {
        'totalRevenue': totalRevenue,
        'revenueByDay': revenueByDay,
      };
    } catch (e) {
      rethrow;
    }
  }
}

