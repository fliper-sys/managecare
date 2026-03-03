import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/pharmacy_repository.dart';

class PharmacyRepositoryImpl implements PharmacyRepository {
  final FirebaseFirestore _firestore;

  PharmacyRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>> getDashboardStats(String businessId) async {
    final now = DateTime.now();

    // Prescriptions today
    final prescSnap = await _firestore
        .collection('prescriptions')
        .where('businessId', isEqualTo: businessId)
        .where('createdAt', isEqualTo: DateTime(now.year, now.month, now.day))
        .get();

    // Expiring soon in inventory (7 days)
    final soon = DateTime.now().add(const Duration(days: 7));
    final expSnap = await _firestore
        .collection('businesses/$businessId/inventory')
        .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(soon))
        .get();

    return <String, dynamic>{
      'prescriptionsToday': prescSnap.docs.length,
      'expiringSoon': expSnap.docs.length,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentPrescriptions(
      String businessId) async {
    final snap = await _firestore
        .collection('prescriptions')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }

  @override
  Future<int> getExpiringItemCount(String businessId) async {
    final soon = DateTime.now().add(const Duration(days: 7));
    final snap = await _firestore
        .collection('businesses/$businessId/inventory')
        .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(soon))
        .get();
    return snap.docs.length;
  }
}

