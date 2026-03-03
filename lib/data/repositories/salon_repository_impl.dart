import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/salon_repository.dart';

class SalonRepositoryImpl implements SalonRepository {
  final FirebaseFirestore _firestore;

  SalonRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Appointments today
    final appointSnap = await _firestore
        .collection('appointments')
        .where('businessId', isEqualTo: businessId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .get();

    // Available slots (simple count: total slots - booked)
    final slotsSnap = await _firestore
        .collection('timeslots')
        .where('businessId', isEqualTo: businessId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .where('isAvailable', isEqualTo: true)
        .get();

    // Revenue today
    final salesSnap = await _firestore
        .collection('sales')
        .where('businessId', isEqualTo: businessId)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .get();

    double totalRevenue = 0;
    for (var doc in salesSnap.docs) {
      totalRevenue += (doc['totalAmount'] as num? ?? 0).toDouble();
    }

    return <String, dynamic>{
      'appointments': appointSnap.docs.length,
      'availableSlots': slotsSnap.docs.length,
      'revenue': totalRevenue,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getTodayAppointments(
      String businessId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snap = await _firestore
        .collection('appointments')
        .where('businessId', isEqualTo: businessId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .orderBy('date')
        .limit(10)
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getStylists(String businessId) async {
    final snap = await _firestore
        .collection('workers')
        .where('businessId', isEqualTo: businessId)
        .where('role', isEqualTo: 'Stylist')
        .limit(10)
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }
}

