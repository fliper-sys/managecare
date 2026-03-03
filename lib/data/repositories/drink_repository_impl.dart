import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/drink_repository.dart';

class DrinkRepositoryImpl implements DrinkRepository {
  final FirebaseFirestore _firestore;

  DrinkRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> getBrewingLogs(String businessId) async {
    final snap = await _firestore
        .collection('brewingLogs')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getDistributionOrders(
      String businessId) async {
    final snap = await _firestore
        .collection('distributionOrders')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>> getInventory(String businessId) async {
    final snap = await _firestore
        .collection('businesses/$businessId/inventory')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final List<Map<String, dynamic>> result = snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .toList()
        .cast<Map<String, dynamic>>();
    return result;
  }
}

