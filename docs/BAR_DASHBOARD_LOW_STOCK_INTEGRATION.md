# Bar Dashboard - Low Stock Integration Guide

**Purpose:** Shows exactly how to integrate low stock detection into bar/drinks dashboard  
**Reference Implementation:** `lib/presentation/industry_specific/drink/screens/drink_dashboard_screen.dart`

---

## 📊 Current Bar Dashboard Pattern

The drink/bar dashboard already uses the **Provider-Based Detection Pattern**:

### Current Implementation (Lines 218-220)
```dart
final openOrders = drinkProvider.getOpenOrders();
final lowStock = drinkProvider.getLowStockDrinks();  // ← This is the pattern
```

### Low Stock Method in DrinkProvider (Line 337)
```dart
List<DrinkItem> getLowStockDrinks([int threshold = 6]) {
  return drinks.where((d) => getTotalBottles(d.id) <= threshold).toList();
}
```

### Display on Dashboard (Line 260)
```dart
// Animated Low Stock Alert
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: _buildAlertCard(lowStock.length),
),
```

---

## 🎯 How Bar Dashboard Detects Low Stock

### Step 1: Provider Fetches Data
```dart
// In DrinkProvider
late List<DrinkItem> drinks;  // Cached list
late List<StockItem> inventory;  // Stock tracking

// Load drinks on startup
Future<void> loadDrinks() async {
  final data = await _repository.fetchDrinks();
  drinks = data;
  notifyListeners();  // Notify dashboard of changes
}
```

### Step 2: Dashboard Calculates Low Stock
```dart
// In drink_dashboard_screen.dart
final lowStock = drinkProvider.getLowStockDrinks();  // Get low stock drinks
```

### Step 3: Display Count as Metric
```dart
// Line 260 - Show alert card with count
_buildAlertCard(lowStock.length)

// Line 257 - Show in stats
_buildStatCard(
  icon: '📋',
  label: 'Open Orders',
  value: '${openOrders.length}',  // Similar pattern
  color: const Color(0xFF42A5F5),
)
```

### Step 4: Visual Indicator on Each Item
```dart
// Line 321 - For each drink in list
final isLow = total <= 6;  // Check if low stock
// Show red/orange badge if true
```

---

## 🔄 Apply This Pattern to Other Dashboards

### 1. Barber Shop Dashboard

**Add to BarberShopProvider:**
```dart
class BarberShopProvider extends ChangeNotifier {
  late List<Product> products;
  
  // Add this method (same pattern as DrinkProvider)
  List<Product> getLowStockProducts([int threshold = 5]) {
    return products.where((p) => p.quantity <= threshold).toList();
  }
}
```

**Add to barber_shop_dashboard_screen.dart:**
```dart
Widget build(BuildContext context) {
  return Consumer<BarberShopProvider>(
    builder: (context, provider, _) {
      // Get low stock items (same as drinks dashboard)
      final lowStock = provider.getLowStockProducts(threshold: 5);
      
      return SingleChildScrollView(
        child: Column(
          children: [
            // Existing metrics...
            
            // Add low stock metric (same pattern as drinks)
            _buildStatCard(
              icon: '⚠️',
              label: 'Low Stock',
              value: '${lowStock.length}',
              color: Colors.orange,
            ),
            
            // Optional: Add alert if critical
            if (lowStock.isNotEmpty)
              _buildLowStockAlert(lowStock),
          ],
        ),
      );
    },
  );
}

Widget _buildLowStockAlert(List<Product> items) {
  return Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange[100],
      border: Border.all(color: Colors.orange),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${items.length} items need restocking'),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(
            context,
            Routes.lowStockProducts,
          ),
          child: const Text('View'),
        ),
      ],
    ),
  );
}
```

---

### 2. Salon Dashboard

**Pattern is identical - just change threshold and product type:**

```dart
class SalonProvider extends ChangeNotifier {
  late List<Product> services;
  
  List<Product> getLowStockServices([int threshold = 3]) {
    return services.where((s) => s.quantity <= threshold).toList();
  }
}

// In salon_dashboard.dart
final lowStockServices = provider.getLowStockServices(threshold: 3);
_buildStatCard(
  icon: '⚠️',
  label: 'Low Stock',
  value: '${lowStockServices.length}',
  color: Colors.orange,
)
```

---

### 3. Pharmacy Dashboard

**With additional expiry check:**

```dart
class PharmacyProvider extends ChangeNotifier {
  late List<Medicine> medicines;
  
  List<Medicine> getLowStockMedicines([int threshold = 10]) {
    return medicines
        .where((m) => m.quantity <= threshold && !m.isExpired)
        .toList();
  }
  
  List<Medicine> getCriticalMedicines() {
    return medicines
        .where((m) => m.quantity == 0 || m.isExpired)
        .toList();
  }
}

// In pharmacy_dashboard.dart
final lowStock = provider.getLowStockMedicines(threshold: 10);
final critical = provider.getCriticalMedicines();

// Show both metrics
_buildStatCard(
  icon: '⚠️',
  label: 'Low Stock',
  value: '${lowStock.length}',
  color: Colors.orange,
)

if (critical.isNotEmpty)
  _buildStatCard(
    icon: '🔴',
    label: 'Critical',
    value: '${critical.length}',
    color: Colors.red,
  )
```

---

## 📋 Complete Integration Template

Here's the complete code to add to any dashboard:

```dart
// 1. In provider (e.g., YourBusinessProvider)
class YourBusinessProvider extends ChangeNotifier {
  late List<YourProduct> products;
  
  /// Get products below stock threshold
  /// Default threshold: 5 units (adjust as needed)
  List<YourProduct> getLowStockItems([int threshold = 5]) {
    return products
        .where((p) => p.quantity <= threshold)
        .toList();
  }
  
  /// Get only out-of-stock items (critical)
  List<YourProduct> getCriticalItems() {
    return products.where((p) => p.quantity == 0).toList();
  }
  
  /// Get count for quick display
  int getLowStockCount([int threshold = 5]) {
    return getLowStockItems(threshold).length;
  }
}

// 2. In dashboard screen
class YourDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<YourBusinessProvider>(
      builder: (context, provider, _) {
        // Get low stock items
        final lowStock = provider.getLowStockItems(threshold: 5);
        final critical = provider.getCriticalItems();
        
        return SingleChildScrollView(
          child: Column(
            children: [
              // Existing metrics...
              
              // Add low stock metric card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        icon: '⚠️',
                        label: 'Low Stock',
                        value: '${lowStock.length}',
                        color: Colors.orange,
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.lowStockProducts,
                        ),
                      ),
                    ),
                    if (critical.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          icon: '🔴',
                          label: 'Critical',
                          value: '${critical.length}',
                          color: Colors.red,
                          onTap: () => _showCriticalItems(critical),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Optional: Alert banner if critical
              if (critical.isNotEmpty)
                _buildCriticalAlert(critical),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMetricCard({
    required String icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildCriticalAlert(List<dynamic> items) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[100],
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Critical Stock Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Text(
                  '${items.length} item${items.length > 1 ? 's' : ''} out of stock',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showCriticalItems(items),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
  
  void _showCriticalItems(List<dynamic> items) {
    // Show critical items dialog or navigate to screen
  }
}
```

---

## 🔍 Key Differences by Business Type

| Business | Threshold | Additional Check | Location |
|----------|-----------|------------------|----------|
| **Bar/Drinks** | 6 bottles | Carton calculation | `getTotalBottles()` |
| **Barber/Salon** | 3-5 units | Service availability | Stock only |
| **Pharmacy** | 10 units | Expiry date | + Not expired |
| **Retail** | 10-20 units | Size variants | Per SKU |
| **Restaurant** | Varies | Perishability | By ingredient |
| **Hotel** | 5 units | Room type | Per room class |
| **Auto Repair** | 3 units | Part category | By part type |

---

## 📊 Threshold Recommendations

```dart
// Based on industry type
const Map<String, int> DEFAULT_THRESHOLDS = {
  'bar': 6,              // bottles
  'drinks': 6,           // bottles
  'barber': 5,           // units
  'salon': 3,            // units
  'pharmacy': 10,        // tablets/bottles
  'retail': 20,          // units
  'restaurant': 10,      // units
  'hotel': 5,            // units (per room class)
  'agriculture': 50,     // kg/bags
  'auto_repair': 3,      // units per part
};
```

---

## 🧪 Testing the Integration

### Test 1: Provider Method Works
```dart
test('getLowStockItems filters correctly', () {
  final provider = YourBusinessProvider();
  provider.products = [
    YourProduct(name: 'Item1', quantity: 2),  // Should be included
    YourProduct(name: 'Item2', quantity: 10), // Should NOT be included
  ];
  
  final lowStock = provider.getLowStockItems(threshold: 5);
  expect(lowStock.length, 1);
  expect(lowStock.first.name, 'Item1');
});
```

### Test 2: Dashboard Displays Count
```dart
testWidgets('Dashboard shows low stock count', (tester) async {
  await tester.pumpWidget(const YourDashboardScreen());
  expect(find.text('⚠️'), findsOneWidget);
  expect(find.text('Low Stock'), findsOneWidget);
});
```

### Test 3: Tap Navigation Works
```dart
testWidgets('Tapping low stock card navigates', (tester) async {
  await tester.pumpWidget(const YourDashboardScreen());
  await tester.tap(find.text('Low Stock'));
  await tester.pumpAndSettle();
  expect(find.byType(LowStockProductsScreen), findsOneWidget);
});
```

---

## ✅ Integration Checklist

- [ ] Add `getLowStockItems()` method to provider
- [ ] Add `getCriticalItems()` method (optional)
- [ ] Import provider in dashboard screen
- [ ] Get low stock list in build method
- [ ] Add metric card showing count
- [ ] Add tap action to navigate to details
- [ ] (Optional) Add alert banner if critical
- [ ] Set appropriate threshold for business type
- [ ] Test with various product quantities
- [ ] Verify sorting by quantity (if applicable)
- [ ] Check color coding (orange for low, red for critical)
- [ ] Verify navigation to low_stock_products_screen
- [ ] Test on both light and dark modes
- [ ] Add error handling if provider fails

---

## 🎯 Summary

**The Bar Dashboard Pattern:**
1. Provider caches products in memory
2. Dashboard calls `getLowStockItems()` to filter
3. Display count as metric card
4. Tap card to navigate to detailed screen
5. All updates are real-time via provider listeners

**To Apply to Your Dashboard:**
1. Copy the method to your provider
2. Adjust threshold for your business type
3. Call method in dashboard build
4. Display result as metric/alert
5. Link to low_stock_products_screen

**Files to Reference:**
- `lib/providers/drink_provider.dart` - Live example method (line 337)
- `lib/presentation/industry_specific/drink/screens/drink_dashboard_screen.dart` - Integration example (line 218)
- `LOW_STOCK_DETECTION_QUICK_REFERENCE.md` - General guide

---

## 🚀 Next Steps

1. **Identify your provider** - Find your business provider class
2. **Add the method** - Copy `getLowStockItems()` pattern
3. **Display on dashboard** - Add metric card
4. **Test integration** - Verify counting and navigation
5. **Adjust threshold** - Set for your business type
6. **Add notifications** - Send alerts when critical (optional)
