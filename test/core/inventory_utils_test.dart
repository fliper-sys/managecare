import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/core/utils/inventory_utils.dart';

void main() {
  group('normalizeProcurementQuantity - bag conversions', () {
    test('bag -> kg with bagWeightKg=50', () {
      final normalized = normalizeProcurementQuantity(2, 'bag', 'kg', bagWeightKg: 50);
      expect(normalized, equals(100)); // 2 bags * 50 kg = 100 kg
    });

    test('bag -> g with bagWeightKg=50', () {
      final normalized = normalizeProcurementQuantity(1, 'bag', 'g', bagWeightKg: 50);
      expect(normalized, equals(50000)); // 1 bag * 50 kg = 50000 g
    });

    test('bag with zero bagWeightKg falls back to qty', () {
      final normalized = normalizeProcurementQuantity(3, 'bag', 'bag', bagWeightKg: 0);
      expect(normalized, equals(3));
    });
  });
}
