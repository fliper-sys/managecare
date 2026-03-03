import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/retail_repository.dart';

class RetailRepositoryImpl implements RetailRepository {
  final FirebaseFirestore _firestore;

  RetailRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> getWholesaleOrders(
      String businessId) async {
    final snap = await _firestore
        .collection('wholesaleOrders')
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

  @override
  Future<List<Map<String, dynamic>>> getSales(String businessId) async {
    final snap = await _firestore
        .collection('sales')
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
}

