import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/payment_repository.dart';

/// Firebase implementation of payment repository
class PaymentRepositoryImpl implements PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<dynamic> processPayment(Map<String, dynamic> paymentData) async {
    try {
      paymentData['createdAt'] = DateTime.now();
      paymentData['status'] = 'completed';
      final docRef = await _firestore.collection('payments').add(paymentData);
      return {'id': docRef.id, ...paymentData};
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getPaymentById(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getPaymentHistory(String businessId,
      {Map<String, dynamic>? filters}) async {
    try {
      var query = _firestore
          .collection('payments')
          .where('businessId', isEqualTo: businessId);
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> refundPayment(String paymentId) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': 'refunded',
        'refundedAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }
}

