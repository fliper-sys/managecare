import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';

/// Firebase implementation of customer repository
class CustomerRepositoryImpl implements CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<dynamic> addCustomer(Map<String, dynamic> customerData) async {
    try {
      final rawData = Map<String, dynamic>.from(customerData);
      final businessId = _normalizeString(rawData['businessId']);
      final rootDocRef = _firestore.collection('customers').doc();
      final customerId = rootDocRef.id;
      final normalizedData = _normalizeCustomerData(
        rawData,
        customerId: customerId,
        businessId: businessId,
      );

      if (businessId != null) {
        final batch = _firestore.batch();
        batch.set(
          _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('customers')
              .doc(customerId),
          normalizedData,
          SetOptions(merge: true),
        );
        batch.set(rootDocRef, normalizedData, SetOptions(merge: true));
        await batch.commit();
      } else {
        await rootDocRef.set(normalizedData, SetOptions(merge: true));
      }

      return normalizedData;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateCustomer(
    String customerId,
    Map<String, dynamic> customerData,
  ) async {
    try {
      final rawData = Map<String, dynamic>.from(customerData);
      var businessId = _normalizeString(rawData['businessId']);
      Map<String, dynamic> existingData = const <String, dynamic>{};

      final topDoc =
          await _firestore.collection('customers').doc(customerId).get();
      if (topDoc.exists) {
        existingData = topDoc.data() ?? const <String, dynamic>{};
      } else if (businessId != null) {
        final scopedDoc = await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('customers')
            .doc(customerId)
            .get();
        if (scopedDoc.exists) {
          existingData = scopedDoc.data() ?? const <String, dynamic>{};
        }
      }

      final mergedData = <String, dynamic>{
        ...existingData,
        ...rawData,
      };
      businessId ??= _normalizeString(existingData['businessId']);
      final normalizedData = _normalizeCustomerData(
        mergedData,
        customerId: customerId,
        businessId: businessId,
      );

      await _firestore
          .collection('customers')
          .doc(customerId)
          .set(normalizedData, SetOptions(merge: true));

      if (businessId != null) {
        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('customers')
            .doc(customerId)
            .set(normalizedData, SetOptions(merge: true));
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteCustomer(String customerId) async {
    try {
      final topDocRef = _firestore.collection('customers').doc(customerId);
      final topDoc = await topDocRef.get();
      if (topDoc.exists) {
        final businessId = _normalizeString(topDoc.data()?['businessId']);
        if (businessId != null) {
          try {
            await _firestore
                .collection('businesses')
                .doc(businessId)
                .collection('customers')
                .doc(customerId)
                .delete();
          } catch (_) {
            // Ignore best-effort scoped delete failures.
          }
        }
        await topDocRef.delete();
        return;
      }

      await topDocRef.delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getCustomers(
    String businessId, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('customers')
          .get();

      return snapshot.docs
          .map(
            (doc) => CustomerModel.normalizeFirestoreData(
              doc.data(),
              documentId: doc.id,
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getCustomerById(String customerId) async {
    try {
      final topDoc =
          await _firestore.collection('customers').doc(customerId).get();
      if (topDoc.exists) {
        return CustomerModel.normalizeFirestoreData(
          topDoc.data() ?? const <String, dynamic>{},
          documentId: topDoc.id,
        );
      }

      final scopedSnapshot = await _firestore
          .collectionGroup('customers')
          .where(FieldPath.documentId, isEqualTo: customerId)
          .limit(1)
          .get();

      if (scopedSnapshot.docs.isEmpty) return null;

      final scopedDoc = scopedSnapshot.docs.first;
      return CustomerModel.normalizeFirestoreData(
        scopedDoc.data(),
        documentId: scopedDoc.id,
      );
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
          .orderBy('totalSpent', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map(
            (doc) => CustomerModel.normalizeFirestoreData(
              doc.data(),
              documentId: doc.id,
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCustomers({
    String? businessId,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (businessId != null && businessId.isNotEmpty) {
        snapshot = await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('customers')
            .get();
      } else {
        snapshot = await _firestore.collection('customers').get();
      }

      return snapshot.docs
          .map(
            (doc) => CustomerModel.normalizeFirestoreData(
              doc.data(),
              documentId: doc.id,
            ),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> syncCustomerToFirestore(
    Map<String, dynamic> customerData,
  ) async {
    try {
      final rawData = Map<String, dynamic>.from(customerData);
      final businessId = _normalizeString(rawData['businessId']);
      final customerId = _normalizeString(rawData['id']) ??
          _normalizeString(rawData['customerId']) ??
          _firestore.collection('customers').doc().id;
      final normalizedData = _normalizeCustomerData(
        rawData,
        customerId: customerId,
        businessId: businessId,
      );

      if (businessId != null) {
        final batch = _firestore.batch();
        batch.set(
          _firestore
              .collection('businesses')
              .doc(businessId)
              .collection('customers')
              .doc(customerId),
          normalizedData,
          SetOptions(merge: true),
        );
        batch.set(
          _firestore.collection('customers').doc(customerId),
          normalizedData,
          SetOptions(merge: true),
        );
        await batch.commit();
      } else {
        await _firestore
            .collection('customers')
            .doc(customerId)
            .set(normalizedData, SetOptions(merge: true));
      }
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeCustomerData(
    Map<String, dynamic> customerData, {
    required String customerId,
    String? businessId,
  }) {
    final source = Map<String, dynamic>.from(customerData);
    source['id'] = customerId;
    source['customerId'] = customerId;
    if (businessId != null && businessId.isNotEmpty) {
      source['businessId'] = businessId;
    }
    return CustomerModel.normalizeFirestoreData(
      source,
      documentId: customerId,
    );
  }

  String? _normalizeString(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }
}
