import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/customer_repository.dart';

/// Firebase implementation of customer repository
class CustomerRepositoryImpl implements CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<dynamic> addCustomer(Map<String, dynamic> customerData) async {
    try {
      customerData['createdAt'] = DateTime.now();
      customerData['updatedAt'] = DateTime.now();
      final bid = customerData['businessId'] as String?;
      if (bid != null && bid.isNotEmpty) {
        final docRef = _firestore
            .collection('businesses')
            .doc(bid)
            .collection('customers')
            .doc();
        await docRef.set(customerData);
        // Also write a top-level customers document with the same id to simplify lookups
        try {
          await _firestore
              .collection('customers')
              .doc(docRef.id)
              .set({...customerData, 'businessId': bid});
        } catch (_) {
          // ignore mirror failure - main record is the business-scoped doc
        }
        return {'id': docRef.id, ...customerData};
      }
      final docRef = await _firestore.collection('customers').add(customerData);
      return {'id': docRef.id, ...customerData};
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateCustomer(
      String customerId, Map<String, dynamic> customerData) async {
    try {
      customerData['updatedAt'] = DateTime.now();
      // Update top-level customers doc (create/merge if needed)
      await _firestore
          .collection('customers')
          .doc(customerId)
          .set(customerData, SetOptions(merge: true));

      // If businessId present, also update the business-scoped customer doc
      final bid = customerData['businessId'] as String?;
      if (bid != null && bid.isNotEmpty) {
        await _firestore
            .collection('businesses')
            .doc(bid)
            .collection('customers')
            .doc(customerId)
            .set(customerData, SetOptions(merge: true));
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteCustomer(String customerId) async {
    try {
      // Try deleting top-level doc and, if it contains a businessId, delete the business-scoped doc as well
      final topDocRef = _firestore.collection('customers').doc(customerId);
      final topDoc = await topDocRef.get();
      if (topDoc.exists) {
        final bid = (topDoc.data()?['businessId'] as String?) ?? '';
        if (bid.isNotEmpty) {
          try {
            await _firestore
                .collection('businesses')
                .doc(bid)
                .collection('customers')
                .doc(customerId)
                .delete();
          } catch (_) {
            // ignore - best-effort
          }
        }
        await topDocRef.delete();
        return;
      }

      // Fallback - attempt to delete top-level doc (idempotent)
      await topDocRef.delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getCustomers(String businessId,
      {Map<String, dynamic>? filters}) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('customers')
          .get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> row =
            Map<String, dynamic>.from(doc.data() as Map);
        row['id'] = doc.id;
        return row;
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getCustomerById(String customerId) async {
    try {
      final doc =
          await _firestore.collection('customers').doc(customerId).get();
      if (!doc.exists) return null;
      return {
        ...doc.data() ?? {},
        'id': doc.id,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getTopCustomers(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('customers')
          .orderBy('totalPurchases', descending: true)
          .limit(10)
          .get();
      return snapshot.docs.map((doc) {
        final Map<String, dynamic> row =
            Map<String, dynamic>.from(doc.data() as Map);
        row['id'] = doc.id;
        return row;
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCustomers(
      {String? businessId}) async {
    try {
      QuerySnapshot snapshot;
      if (businessId != null) {
        snapshot = await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('customers')
            .get();
      } else {
        snapshot = await _firestore.collection('customers').get();
      }
      return snapshot.docs
          .map((doc) {
            final Map<String, dynamic> row =
                Map<String, dynamic>.from(doc.data() as Map);
            row['id'] = doc.id;
            return row;
          })
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> syncCustomerToFirestore(
      Map<String, dynamic> customerData) async {
    try {
      final customerId = customerData['id'] as String?;
      final bid = customerData['businessId'] as String?;
      if (bid != null && bid.isNotEmpty) {
        if (customerId != null) {
          await _firestore
              .collection('businesses')
              .doc(bid)
              .collection('customers')
              .doc(customerId)
              .set(customerData, SetOptions(merge: true));
        } else {
          final docRef = _firestore
              .collection('businesses')
              .doc(bid)
              .collection('customers')
              .doc();
          await docRef.set(customerData);
        }
      } else {
        if (customerId != null) {
          await _firestore
              .collection('customers')
              .doc(customerId)
              .set(customerData, SetOptions(merge: true));
        } else {
          await _firestore.collection('customers').add(customerData);
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}

