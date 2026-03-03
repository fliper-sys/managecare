import 'package:flutter_test/flutter_test.dart';
import '../../lib/presentation/industry_specific/salon/providers/salon_provider.dart';

void main() {
  test('ProductItem JSON roundtrip', () {
    final p = ProductItem(id: 'p1', name: 'Shampoo', quantity: 5, price: 10.5, minStock: 2, reorderQuantity: 20);
    final json = p.toJson();
    final restored = ProductItem.fromJson({'id': json['id'], ...json});
    expect(restored.id, equals('p1'));
    expect(restored.name, equals('Shampoo'));
    expect(restored.quantity, equals(5));
    expect(restored.price, equals(10.5));
    expect(restored.minStock, equals(2));
    expect(restored.reorderQuantity, equals(20));
  });

  test('adjustProductQuantityLocal updates quantity correctly', () {
    final provider = SalonProvider();

    final p = ProductItem(id: 'p1', name: 'Shampoo', quantity: 5, price: 10.5);
    provider.setProductsForTesting([p]);

    provider.adjustProductQuantityLocal('p1', 3);
    expect(provider.products.first.quantity, equals(8));

    provider.adjustProductQuantityLocal('p1', -10);
    expect(provider.products.first.quantity, equals(0));
  });
}
