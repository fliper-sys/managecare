import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/presentation/inventory/utils/distributor_sales_analytics.dart';

void main() {
  group('DistributorSalesAnalytics', () {
    test('summarizes sales totals and counts correctly', () {
      final analytics = DistributorSalesAnalytics.summarize([
        {
          'quantity': 3,
          'totalAmount': 3000,
          'distributorName': 'Kola Supply',
        },
        {
          'quantity': 2,
          'totalAmount': 2500,
          'distributorName': 'Kola Supply',
        },
        {
          'quantity': 4,
          'totalAmount': 4000,
          'distributorName': 'Ada Foods',
        },
      ]);

      expect(analytics.saleCount, 3);
      expect(analytics.totalQuantity, 9);
      expect(analytics.totalAmount, 9500);
      expect(analytics.distributorCount, 2);
    });
  });
}
