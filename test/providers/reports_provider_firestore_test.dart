import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/providers/reports_provider.dart';

void main() {
  test('buildWarehouseSalesFromRaw aggregates totals and labels', () {
    final salesDocs = [
      {'warehouseId': 'w1', 'totalAmount': 100.0},
      {'warehouseId': 'w1', 'totalAmount': 150.0},
      {'warehouseId': 'w2', 'totalAmount': 200.0},
      {'totalAmount': 50.0}, // unassigned
    ];

    final warehouseNames = {
      'w1': 'Main Warehouse',
      'w2': 'Branch A',
    };

    final result = ReportsProvider.buildWarehouseSalesFromRaw(salesDocs, warehouseNames);

    expect(result.length, 3);
    expect(result.first.warehouseId, 'w1');
    expect(result.first.total, 250.0);

    final byId = {for (var r in result) r.warehouseId: r};
    expect(byId['w2']!.total, 200.0);
    expect(byId['unassigned']!.total, 50.0);
    expect(byId['w1']!.warehouseName, 'Main Warehouse');
    expect(byId['unassigned']!.warehouseName, 'Unassigned');
  });
}
