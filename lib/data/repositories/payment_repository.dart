abstract class PaymentRepository {
  Future<Map<String, dynamic>> processPayment(Map<String, dynamic> paymentInfo);
  Future<Map<String, dynamic>?> getPayment(String id);
  Future<List<Map<String, dynamic>>> fetchPayments(String businessId);
}

