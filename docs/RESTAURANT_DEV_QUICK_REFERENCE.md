# Restaurant Module - Developer Quick Reference

## Quick Navigation Map

```
┌─────────────────────────────────────────────────────────────┐
│                    RESTAURANT MODULE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  OWNER ENTRY POINT                                         │
│  └─ Select 'Restaurant' in Business Dashboard             │
│     └─ Displays: RestaurantOwnerDashboard                 │
│        ├─ Analytics (Revenue, Orders, Tables, Bookings)  │
│        └─ View recent activities                          │
│                                                             │
│  WORKER ENTRY POINTS                                       │
│  ├─ Route: /restaurant/menu                               │
│  │  └─ CreateOrderScreen                                  │
│  │     ├─ Select table                                    │
│  │     ├─ Browse menu                                     │
│  │     ├─ Create order                                    │
│  │     └─ Print kitchen & customer receipts              │
│  │                                                         │
│  ├─ Route: /restaurant/orders                             │
│  │  └─ PendingOrdersAndCheckoutScreen                    │
│  │     ├─ View orders by status                          │
│  │     ├─ Process payment                                │
│  │     └─ Generate receipt & save to history             │
│  │                                                         │
│  └─ Route: /restaurant/reservations                       │
│     └─ RestaurantWorkerOnboarding                         │
│        └─ 6-step training guide                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
lib/presentation/industry_specific/restaurant/
├── providers/
│   └── restaurant_provider.dart          # State management
│       ├─ MenuItem class
│       ├─ OrderItem class
│       ├─ TableInfo class
│       ├─ RestaurantOrder class
│       ├─ Reservation class
│       └─ RestaurantProvider class
│
├── screens/
│   ├── restaurant_owner_dashboard.dart   # Owner view
│   ├── create_order_screen.dart          # Order creation
│   ├── pending_orders_checkout_screen.dart # Payment & checkout
│   └── restaurant_worker_onboarding.dart # Worker training
│
└── widgets/
    ├── restaurant_cart_sheet.dart
    ├── beautiful_menu_item_card.dart
    ├── menu_item_card.dart
    ├── order_card.dart
    ├── modifier_selector.dart
    ├── order_type_selector.dart
    ├── table_card.dart
    └── kitchen_ticket.dart
```

## Route Access Pattern

### For Owners (from Business Dashboard)
```dart
// In owner_dashboard_screen.dart
switch (business.businessType.toLowerCase()) {
  case 'restaurant':
    screen = const RestaurantOwnerDashboard();
    break;
  // ... other business types
}
```

### For Workers (via Route Navigation)
```dart
// Navigate to create order screen
Navigator.pushNamed(context, Routes.restaurantMenu);
// This loads: CreateOrderScreen()

// Navigate to checkout
Navigator.pushNamed(context, Routes.restaurantOrders);
// This loads: PendingOrdersAndCheckoutScreen()

// Navigate to worker onboarding
Navigator.pushNamed(context, Routes.restaurantReservations);
// This loads: RestaurantWorkerOnboarding()
```

## Provider Usage in Screens

### RestaurantOwnerDashboard
```dart
Consumer<RestaurantProvider>(
  builder: (context, provider, _) {
    final dailyStats = provider.getDailyStats();
    final orders = provider.getOrdersByStatus('pending');
    // ... build UI
  }
)
```

### CreateOrderScreen
```dart
// Initialize orders
context.read<RestaurantProvider>().initializeOrders();

// Create new order
provider.createOrder(
  tableId: _selectedTableId!,
  items: _selectedItems.values.toList(),
)
```

### PendingOrdersAndCheckoutScreen
```dart
// Get orders by status
final pendingOrders = provider.getOrdersByStatus('pending');
final preparingOrders = provider.getOrdersByStatus('preparing');

// Update order status
context.read<RestaurantProvider>().updateOrderStatus(
  _selectedOrderId!, 
  'completed'
);
```

## Key Classes & Methods

### RestaurantProvider (Full API)

**Initialization**
- `initializeMenu()` - Load menu items
- `initializeOrders()` - Load orders
- `initializeTables()` - Load tables
- `initializeReservations()` - Load reservations

**Menu Operations**
- `addMenuItem(item)` - Add new menu item
- `updateMenuItem(id, item)` - Update item
- `deleteMenuItem(id)` - Remove item
- `getMenuByCategory(category)` - Filter menu

**Order Operations**
- `createOrder(tableId, items)` - Create order
- `updateOrderStatus(orderId, status)` - Change order status
- `assignChefToOrder(orderId, chefId)` - Assign chef
- `assignWaiterToOrder(orderId, waiterId)` - Assign waiter
- `getOrdersByStatus(status)` - Filter by status
- `getOrdersByTableId(tableId)` - Filter by table

**Table Operations**
- `updateTableStatus(tableId, status)` - Update table (available/occupied/reserved)
- `assignWaiterToTable(tableId, waiterId)` - Assign waiter
- `getAvailableTables()` - Get unoccupied tables

**Reservation Operations**
- `createReservation(booking)` - Create reservation
- `updateReservationStatus(id, status)` - Update status
- `getTodayReservations()` - Get today's bookings

**Analytics**
- `getDailyStats()` - Get today's metrics
- `getOrderStats()` - Get order breakdown

### RestaurantOrder Status Values
```
'pending'    - Order created, awaiting kitchen
'preparing'  - Chef is preparing
'ready'      - Ready to serve
'served'     - Served to customer
'completed'  - Payment processed
'cancelled'  - Order cancelled
```

### TableInfo Status Values
```
'available'  - Empty, ready for guests
'occupied'   - Guests seated
'reserved'   - Booking made but not yet seated
'maintenance'- Being cleaned/repaired
```

## Common Operations

### Create an Order
```dart
final orderItems = [
  OrderItem(
    id: 'item1',
    menuItemId: 'pasta_001',
    menuItemName: 'Spaghetti Carbonara',
    price: 8.99,
    quantity: 2,
    specialInstructions: 'Extra cheese',
  ),
];

context.read<RestaurantProvider>().createOrder(
  tableId: 'table_5',
  items: orderItems,
);
```

### Process Payment
```dart
// Create transaction record
final sale = PaymentTransaction(
  id: 'sale_${DateTime.now().millisecondsSinceEpoch}',
  businessId: 'business_001',
  amount: order.total,
  method: paymentMethod, // 'cash' or 'card'
  status: 'completed',
  orderId: order.id,
  createdAt: DateTime.now(),
);

// Update order status
context.read<RestaurantProvider>().updateOrderStatus(
  orderId,
  'completed'
);
```

### Get Analytics
```dart
final stats = context.read<RestaurantProvider>().getDailyStats();

print('Total Revenue: ${stats.totalRevenue}');
print('Total Orders: ${stats.totalOrders}');
print('Avg Order Value: ${stats.avgOrderValue}');
print('Orders by Status: ${stats.ordersByStatus}');
```

## Styling & Theme

### Colors (from AppColors)
- `primary` - Primary action color
- `success` - Success/ready status
- `warning` - Pending/waiting status
- `error` - Cancelled/error status
- `background` - Default background

### Text Styles (from AppTextStyles)
- `heading1-4` - Titles
- `body1-2` - Body text
- `caption` - Small text
- `button` - Button text

## Error Handling

Most provider methods are synchronous and operate on local state. For production:

```dart
try {
  context.read<RestaurantProvider>().createOrder(
    tableId: tableId,
    items: items,
  );
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Order created successfully')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: ${e.toString()}')),
  );
}
```

## Testing Helpers

### Test Imports
```dart
import 'package:business_manager/presentation/industry_specific/restaurant/providers/restaurant_provider.dart';
import 'package:business_manager/presentation/industry_specific/restaurant/screens/create_order_screen.dart';
```

### Sample Data
RestaurantProvider initializes with sample data:
- 5 menu items
- 5 tables (mixed status)
- 2 sample orders
- 2 sample reservations

Access in tests:
```dart
final provider = RestaurantProvider();
final menuItems = provider.menu; // List<MenuItem>
final orders = provider.orders;  // List<RestaurantOrder>
final tables = provider.tables;  // List<TableInfo>
```

## Troubleshooting

### Provider not updating
- Ensure `notifyListeners()` is called after state changes
- Use `Consumer<RestaurantProvider>` or `context.read()` for access

### Routes not resolving
- Check `lib/routes/app_router.dart` for route case
- Verify route name in `lib/core/constants/routes.dart`
- Import screens at top of app_router.dart

### Screens not displaying
- Verify RestaurantProvider is in MultiProvider (line 156 of main.dart)
- Check screen constructors for required parameters
- Use Consumer widget for provider access

## Next Enhancements

- [ ] Real-time order notifications
- [ ] Kitchen display system (KDS)
- [ ] Table reservation management UI
- [ ] Menu management interface
- [ ] Staff scheduling
- [ ] Payment processor integration
- [ ] Inventory tracking integration
- [ ] Customer loyalty system

