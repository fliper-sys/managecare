/// Abstract payment repository
abstract class PaymentRepository {
  Future<dynamic> processPayment(Map<String, dynamic> paymentData);
  Future<dynamic> getPaymentById(String paymentId);
  Future<List<dynamic>> getPaymentHistory(String businessId,
      {Map<String, dynamic>? filters});
  Future<void> refundPayment(String paymentId);
}

