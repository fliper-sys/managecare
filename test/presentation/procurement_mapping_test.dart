import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/core/utils/inventory_utils.dart';

void main() {
  test('selected unit ton converts to kg for product unit kg', () {
    final prod = {'id': 'p1', 'name': 'Gas', 'unit': 'kg'};
    final entry = {'quantity': 2, 'cost': 10.0, 'unit': 'ton', 'product': prod};

    final selectedUnit = (entry['unit'] as String?) ?? (prod['unit'] ?? '');
    final baseUnit = (prod['unit'] ?? '').toString();
    final qty = entry['quantity'] as int;
    final normalizedQty = normalizeProcurementQuantity(qty, selectedUnit, baseUnit.isNotEmpty ? baseUnit : selectedUnit);

    expect(normalizedQty, 2000);
  });
}
