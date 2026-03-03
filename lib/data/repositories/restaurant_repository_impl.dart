import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/restaurant_repository.dart';

class RestaurantRepositoryImpl implements RestaurantRepository {
  final FirebaseFirestore _firestore;

  RestaurantRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final tablesSnap = await _firestore
        .collection('tables')
        .where('businessId', isEqualTo: businessId)
        .get();

    final activeCount = tablesSnap.docs
        .where((d) => (d['status'] as String? ?? '') == 'Occupied')
        .length;
    final totalTables = tablesSnap.docs.length;

    final ordersSnap = await _firestore
        .collection('orders')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'Preparing')
        .get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final revenueSnap = await _firestore
        .collection('sales')
        .where('businessId', isEqualTo: businessId)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .get();

    double totalRevenue = 0;
    for (var doc in revenueSnap.docs) {
      totalRevenue += (doc['totalAmount'] as num? ?? 0).toDouble();
    }

    return <String, dynamic>{
      'activeTables': activeCount,
      'totalTables': totalTables,
      'kitchenQueue': ordersSnap.docs.length,
      'revenue': totalRevenue,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getTables(String businessId) async {
    final snap = await _firestore
        .collection('tables')
        .where('businessId', isEqualTo: businessId)
        .orderBy('number')
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveOrders(String businessId) async {
    final snap = await _firestore
        .collection('orders')
        .where('businessId', isEqualTo: businessId)
        .where('status', whereIn: ['Preparing', 'Ready'])
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }
}

