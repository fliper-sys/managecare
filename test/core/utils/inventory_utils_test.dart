import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/core/utils/inventory_utils.dart';

void main() {
  group('canonicalizeInventoryUnit', () {
    test('normalizes common aliases', () {
      expect(canonicalizeInventoryUnit('pcs'), 'pc');
      expect(canonicalizeInventoryUnit('liter'), 'L');
      expect(canonicalizeInventoryUnit('ml'), 'mL');
      expect(canonicalizeInventoryUnit('cyl'), 'cylinder');
    });
  });

  group('getCompatibleProcurementUnits', () {
    test('returns piece-compatible units for pc inventory', () {
      expect(getCompatibleProcurementUnits('pc'), containsAll(['pc', 'dozen']));
    });

    test('returns weight-compatible units for kg inventory', () {
      expect(
        getCompatibleProcurementUnits('kg'),
        containsAll(['kg', 'g', 'ton']),
      );
    });
  });

  group('normalizeProcurementQuantity', () {
    test('converts ton to kg when base unit is kg', () {
      expect(normalizeProcurementQuantity(1, 'ton', 'kg'), 1000);
      expect(normalizeProcurementQuantity(2, 'ton', 'kg'), 2000);
    });

    test('converts grams to kilograms and millilitres to litres', () {
      expect(normalizeProcurementQuantity(500, 'g', 'kg'), 0.5);
      expect(normalizeProcurementQuantity(1500, 'mL', 'L'), 1.5);
    });

    test('converts dozens to pieces', () {
      expect(normalizeProcurementQuantity(2, 'dozen', 'pc'), 24);
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
