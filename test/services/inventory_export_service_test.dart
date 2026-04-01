import 'package:business_manager/services/inventory_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildCsv includes headers and formatted inventory rows', () {
    final csv = InventoryExportService.buildCsv([
      {
        'id': 'p1',
        'name': 'Rice 50kg',
        'category': 'Food',
        'sku': 'SKU-001',
        'barcode': '123456',
        'quantity': 2,
        'unit': 'bag',
        'minStock': 3,
        'price': 45000,
      },
      {
        'id': 'p2',
        'name': 'Olive Oil',
        'category': 'Groceries',
        'quantity': 1.5,
        'unit': 'L',
        'minStock': 1,
        'price': 12000.5,
      },
    ]);

    expect(csv, contains('Product ID,Product Name,Category,SKU,Barcode,Quantity,Unit,Min Stock,Unit Price,Total Value,Status'));
    expect(csv, contains('"Rice 50kg"'));
    expect(csv, contains('"bag"'));
    expect(csv, contains('"Low Stock"'));
    expect(csv, contains('"1.5"'));
    expect(csv, contains('"L"'));
  });
}
