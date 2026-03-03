import 'package:cloud_firestore/cloud_firestore.dart';
import 'payroll_repository.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  final FirebaseFirestore _firestore;

  PayrollRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<List<Map<String, dynamic>>> getPayrollRecords(
    String businessId,
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('payroll')
          .where('businessId', isEqualTo: businessId)
          .where('workerId', isEqualTo: workerId)
          .orderBy('payDate', descending: true);

      if (startDate != null) {
        query = query.where('payDate', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('payDate', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getPayrollSummary(
    String businessId,
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      DateTime start = startDate ?? DateTime(DateTime.now().year, 1, 1);
      DateTime end = endDate ?? DateTime.now();

      final snapshot = await _firestore
          .collection('payroll')
          .where('businessId', isEqualTo: businessId)
          .where('workerId', isEqualTo: workerId)
          .where('payDate', isGreaterThanOrEqualTo: start)
          .where('payDate', isLessThanOrEqualTo: end)
          .get();

      double totalGross = 0;
      double totalDeductions = 0;
      double totalNetPay = 0;

      for (var doc in snapshot.docs) {
        totalGross += (doc['grossAmount'] as num?)?.toDouble() ?? 0;
        totalDeductions += (doc['deductions'] as num?)?.toDouble() ?? 0;
        totalNetPay += (doc['netAmount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'totalGross': totalGross,
        'totalDeductions': totalDeductions,
        'totalNetPay': totalNetPay,
        'paymentCount': snapshot.docs.length,
        'averagePayment':
            snapshot.docs.isNotEmpty ? totalNetPay / snapshot.docs.length : 0,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> recordPayroll(
    String businessId,
    String workerId,
    Map<String, dynamic> payrollData,
  ) async {
    try {
      await _firestore.collection('payroll').add({
        'businessId': businessId,
        'workerId': workerId,
        ...payrollData,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePayroll(
    String businessId,
    String payrollId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection('payroll')
          .doc(payrollId)
          .update({...updates, 'updatedAt': DateTime.now()});
    } catch (e) {
      rethrow;
    }
  }
}

