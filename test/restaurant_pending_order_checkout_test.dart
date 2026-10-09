import 'package:business_manager/presentation/industry_specific/restaurant/providers/restaurant_provider.dart';
import 'package:business_manager/presentation/industry_specific/restaurant/screens/pending_orders_checkout_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restaurant checkout breakdown includes each item with quantity and amount', () {
    final order = RestaurantOrder(
      id: 'ord-123',
      businessId: 'biz-1',
      tableNumber: 5,
      items: [
        OrderItem(
          id: 'line-1',
          menuItemId: 'm1',
          menuItemName: 'Burger',
          price: 12.5,
          quantity: 2,
          subtotal: 25.0,
        ),
        OrderItem(
          id: 'line-2',
          menuItemId: 'm2',
          menuItemName: 'Fries',
          price: 4.0,
          quantity: 1,
          subtotal: 4.0,
        ),
      ],
      subtotal: 29.0,
      tax: 2.9,
      discount: 0.0,
      total: 31.9,
    );

    final breakdown = buildRestaurantOrderChargeBreakdown(order);

    expect(breakdown.length, 2);
    expect(breakdown[0].label, 'Burger');
    expect(breakdown[0].quantity, 2);
    expect(breakdown[0].total, 25.0);
    expect(breakdown[1].label, 'Fries');
    expect(breakdown[1].total, 4.0);
  });
}
