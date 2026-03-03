import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/core/utils/inventory_utils.dart';

void main() {
  group('normalizeProcurementQuantity', () {
    test('converts ton to kg when base unit is kg', () {
      expect(normalizeProcurementQuantity(1, 'ton', 'kg'), 1000);
      expect(normalizeProcurementQuantity(2, 'ton', 'kg'), 2000);
    });

    test('does not convert when units match', () {
      expect(normalizeProcurementQuantity(5, 'kg', 'kg'), 5);
      expect(normalizeProcurementQuantity(3, 'pcs', 'pcs'), 3);
    });

    test('uses selectedUnit if baseUnit empty', () {
      expect(normalizeProcurementQuantity(1, 'ton', ''), 1); // no base, don't convert
    });
  });
}
