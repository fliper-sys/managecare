import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/core/utils/distributor_sale_utils.dart';

void main() {
  group('Distributor sale calculations', () {
    test('calculates discounted total from quantity and preset discount', () {
      final total = calculateDistributorSaleTotal(
        unitPrice: 100,
        quantity: 3,
        discountPercent: 10,
      );

      expect(total, 270.0);
    });

    test('returns zero for invalid values', () {
      final total = calculateDistributorSaleTotal(
        unitPrice: 0,
        quantity: 0,
        discountPercent: 20,
      );

      expect(total, 0.0);
    });
  });
}
