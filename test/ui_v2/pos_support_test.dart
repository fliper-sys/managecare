import 'package:business_manager/features/retail/pos/retail_barcode.dart';
import 'package:business_manager/templates/catalogue_cart/catalogue_cart.dart';
import 'package:flutter_test/flutter_test.dart';

const _oil = CatalogueItem(id: 'o', name: 'Palm oil', price: 2500, stock: 40);
const _flour = CatalogueItem(id: 'f', name: 'Flour', price: 20000, wholesalePrice: 18000, stock: 100);

void main() {
  group('permissions are enforced in the cart', () {
    test('a role that cannot edit prices cannot set a custom price', () {
      final c = CartState(canEditPrice: false)..add(_oil);
      c.setOverride('o', 100);
      expect(c.overrides, isEmpty);
      expect(c.subtotal, 2500);
    });

    test('a role that cannot discount cannot set one', () {
      final c = CartState(canDiscount: false)..add(_oil);
      c.setDiscount(500);
      expect(c.discount, 0);
      expect(c.total, 2500);
    });

    test('owners keep both', () {
      final c = CartState()..add(_oil);
      c.setOverride('o', 2000);
      c.setDiscount(100);
      expect(c.total, 1900);
    });

    test('carts saved by an owner restore without custom prices or discount for a restricted role', () {
      final owner = CartSessions();
      owner.active.add(_oil);
      owner.active.setOverride('o', 1000);
      owner.active.setDiscount(200);
      final json = Map<String, Object?>.from(owner.toJson());

      final worker = CartSessions(canEditPrice: false, canDiscount: false);
      worker.restoreFrom(json, {'o': _oil});
      expect(worker.active.qtyOf('o'), 1);
      expect(worker.active.overrides, isEmpty);
      expect(worker.active.discount, 0);
      expect(worker.active.subtotal, 2500);
    });

    test('permissions carry to carts created later', () {
      final s = CartSessions(canEditPrice: false)..create();
      expect(s.active.canEditPrice, isFalse);
    });

    test('wholesale list price still applies without price-edit rights', () {
      final c = CartState(canEditPrice: false)..add(_flour);
      c.setMode(PriceMode.wholesale);
      expect(c.subtotal, 18000);
    });
  });

  group('barcode matching', () {
    final items = [
      (id: 'a', barcode: '6001234567890'),
      (id: 'b', barcode: '6009876543210'),
      (id: 'n', barcode: null),
      (id: 'e', barcode: ''),
    ];

    test('exact code finds the product', () => expect(findIdForBarcode('6009876543210', items), 'b'));
    test('surrounding spaces are ignored', () => expect(findIdForBarcode('  6001234567890 ', items), 'a'));
    test('unknown code finds nothing', () => expect(findIdForBarcode('1111111111111', items), isNull));
    test('empty scan finds nothing', () => expect(findIdForBarcode('   ', items), isNull));
    test('products without a barcode are never matched', () => expect(findIdForBarcode('0', [(id: 'n', barcode: null)]), isNull));
  });
}
