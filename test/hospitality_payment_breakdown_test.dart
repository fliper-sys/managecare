import 'package:business_manager/data/models/payment_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentBreakdown', () {
    test('sums mixed tenders and resolves the method', () {
      const payment = PaymentBreakdown(cash: 20, card: 30, transfer: 50);

      expect(payment.total, 100);
      expect(payment.method, 'mixed');
      expect(payment.isValid, isTrue);
    });

    test('resolves a single tender and rejects invalid amounts', () {
      const cashPayment = PaymentBreakdown(cash: 25);
      const invalidPayment = PaymentBreakdown(cash: -5, card: 15);

      expect(cashPayment.method, 'cash');
      expect(invalidPayment.isValid, isFalse);
    });
  });
}
