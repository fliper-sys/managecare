# Low Stock Detection - Quick Implementation Guide

## 📋 Table of Contents
1. [Quick Start](#quick-start)
2. [Bar Dashboard Pattern](#bar-dashboard-pattern)
3. [Usage Examples](#usage-examples)
4. [Integration Checklist](#integration-checklist)

---

## 🚀 Quick Start

### Option 1: Use the Unified Service (Recommended for All Dashboards)

**For detailed inventory management screens:**

```dart
import '../../services/low_stock_detection_service.dart';

class MyDashboard extends StatefulWidget {
  @override
  State<MyDashboard> createState() => _MyDashboardState();
}

class _MyDashboardState extends State<MyDashboard> {
  late LowStockDetectionService _service;
  
  @override
  void initState() {
    super.initState();
    _service = LowStockDetectionService();
  }

  Future<void> _checkLowStock() async {
    final businessId = Provider.of<BusinessProvider>(context, listen: false)
        .currentBusiness?.id;
    
    if (businessId == null) return;

    // Get low stock products
    final lowStockItems = await _service.detectLowStockProducts(
      businessId: businessId,
      threshold: 10,  // Configurable
      sortByQuantity: true,  // Lowest stock first
    );

    print('Found ${lowStockItems.length} low stock items');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LowStockProduct>>(
      future: _service.detectLowStockProducts(
        businessId: businessProvider.currentBusiness!.id,
        threshold: 10,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final products = snapshot.data ?? [];
        return ListView(
          children: products.map((p) => ListTile(
            title: Text(p.name),
            subtitle: Text('Stock: ${p.quantity} ${p.unit}'),
            trailing: Text(p.formattedLastRestocked),
          )).toList(),
        );
      },
    );
  }
}
```

### Option 2: Use Provider Method (For Provider-Cached Data)

**For Bar/Drinks dashboard with DrinkProvider:**

```dart
final lowStockDrinks = drinkProvider.getLowStockDrinks(threshold: 6);

// Display as metric
_buildStatCard(
  icon: '⚠️',
  label: 'Low Stock',
  value: '${lowStockDrinks.length}',
  color: Colors.orange,
)
```

---

## 📊 Bar Dashboard Pattern

The drink/bar dashboard uses an **in-memory provider method**:

### Current Implementation
```dart
// In DrinkProvider
List<DrinkItem> getLowStockDrinks([int threshold = 6]) {
  return drinks.where((d) => getTotalBottles(d.id) <= threshold).toList();
}
```

### Display on Dashboard
```dart
// In drink_dashboard_screen.dart (line 218)
final lowStock = drinkProvider.getLowStockDrinks();

// Metric card showing count
_buildStatCard(
  icon: '⚠️',
  label: 'Low Stock Items',
  value: '${lowStock.length}',
  color: AppColors.warning,
)

// Visual indicator on each drink card
final isLow = getTotalBottles(drink.id) <= 6;
if (isLow) {
  // Show orange/red badge
}
```

### How to Apply to Other Dashboards

**Barber Shop Dashboard:**
```dart
// Add to BarberShopProvider
List<Product> getLowStockProducts([int threshold = 5]) {
  return products
      .where((p) => p.quantity <= threshold)
      .toList();
}

// Use in barber_shop_dashboard_screen.dart
class _BarberDashboardState extends State<BarberShopDashboard> {
  @override
  Widget build(BuildContext context) {
    return Consumer<BarberShopProvider>(
      builder: (context, provider, _) {
        final lowStockItems = provider.getLowStockProducts(threshold: 5);
        
        return Column(
          children: [
            // Existing cards...
            
            // Add low stock metric
            _buildStatCard(
              icon: '⚠️',
              label: 'Low Stock',
              value: '${lowStockItems.length}',
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(
                context,
                Routes.lowStockProducts,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

**Salon Dashboard:**
```dart
// Add to SalonProvider
List<Product> getLowStockItems([int threshold = 3]) {
  return products
      .where((p) => p.quantity <= threshold)
      .toList();
}

// In salon_dashboard.dart
final lowStockItems = salonProvider.getLowStockItems(threshold: 3);
```

**Pharmacy Dashboard:**
```dart
// Add to PharmacyProvider
List<Medicine> getLowStockMedicines([int threshold = 10]) {
  return medicines
      .where((m) => m.quantity <= threshold && !m.isExpired)
      .toList();
}

// In pharmacy_dashboard.dart
final lowStockMeds = pharmacyProvider.getLowStockMedicines(threshold: 10);
```

---

## 💡 Usage Examples

### Example 1: Simple Metric Display
```dart
// Just show the count on dashboard
Text('Low Stock: ${lowStockItems.length}')
```

### Example 2: Alert Banner
```dart
if (lowStockItems.isNotEmpty)
  Container(
    color: Colors.orange[100],
    child: Row(
      children: [
        const Icon(Icons.warning_amber, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${lowStockItems.length} items need restocking'),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, Routes.lowStockProducts),
          child: const Text('View All'),
        ),
      ],
    ),
  )
```

### Example 3: Quick List View
```dart
// Show first 3 critical items
ListView(
  children: lowStockItems.take(3).map((item) {
    return ListTile(
      title: Text(item.name),
      subtitle: Text('Stock: ${item.quantity}/${item.reorderLevel}'),
      trailing: Icon(
        Icons.warning,
        color: item.quantity == 0 ? Colors.red : Colors.orange,
      ),
    );
  }).toList(),
)
```

### Example 4: Grid of Status Cards
```dart
GridView.count(
  crossAxisCount: 2,
  children: lowStockItems.map((item) {
    return Card(
      color: item.quantity == 0 ? Colors.red[50] : Colors.orange[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${item.quantity} left'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => reorderItem(item),
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }).toList(),
)
```

### Example 5: Real-time Stream Updates
```dart
// Using the detection service for live updates
StreamBuilder<List<LowStockProduct>>(
  stream: _service.streamLowStockProducts(
    businessId: businessId,
    threshold: 10,
  ),
  builder: (context, snapshot) {
    final products = snapshot.data ?? [];
    return Text('${products.length} low stock items');
  },
)
```

---

## 📋 Integration Checklist

### For Unified Service Approach:
- [ ] Import `LowStockDetectionService` in your screen
- [ ] Initialize service in `initState()`
- [ ] Call `detectLowStockProducts()` with businessId and threshold
- [ ] Handle loading state with `CircularProgressIndicator`
- [ ] Handle error state with retry button
- [ ] Handle empty state with positive message
- [ ] Display products with color coding (red/orange/green)
- [ ] Add sorting by quantity ascending
- [ ] Add refresh button to reload data
- [ ] Add threshold adjustment slider if needed
- [ ] Link to detailed inventory screen
- [ ] Test with different product quantities
- [ ] Verify Firestore queries work without indexes

### For Provider Approach:
- [ ] Add `getLowStockXxx()` method to your provider
- [ ] Define threshold (fixed or dynamic)
- [ ] Implement filtering logic (`quantity <= threshold`)
- [ ] Add to dashboard metrics card
- [ ] Add visual indicators (color, icon, badge)
- [ ] Make threshold configurable if needed
- [ ] Test with real data
- [ ] Verify performance (check Dart DevTools)
- [ ] Add error handling
- [ ] Document threshold value for team

---

## 🔧 Common Implementation Issues

### Issue 1: "No Firestore Index"
**Solution:** Client-side filtering is already implemented in the service:
```dart
// ✅ This works without any index
final lowStockItems = snapshot.docs
    .where((doc) {
      final qty = (doc['quantity'] as num?)?.toInt() ?? 0;
      return qty <= threshold;
    })
    .toList();
```

### Issue 2: "Too many Firestore reads"
**Solution:** Use pagination or cache:
```dart
// Cache the results for 5 minutes
final cachedResults = _cache.get(businessId);
if (cachedResults != null && 
    DateTime.now().difference(cachedResults.timestamp).inMinutes < 5) {
  return cachedResults.products;
}
```

### Issue 3: "Threshold not updating"
**Solution:** Use `setState()` to trigger rebuild:
```dart
void _updateThreshold(int newThreshold) {
  setState(() {
    _minStockThreshold = newThreshold;
    _loadLowStockProducts();  // Reload with new threshold
  });
}
```

### Issue 4: "Performance lag with many products"
**Solution:** Use streaming and pagination:
```dart
// Stream for real-time updates
_service.streamLowStockProducts(businessId: businessId)

// Or paginate results
final first10 = lowStockItems.take(10).toList();
```

---

## 📊 Service Methods Reference

```dart
// Get low stock products with configurable threshold
Future<List<LowStockProduct>> detectLowStockProducts({
  required String businessId,
  int threshold = 10,
  bool sortByQuantity = true,
})

// Get just the count
Future<int> getLowStockCount({
  required String businessId,
  int threshold = 10,
})

// Get only out-of-stock items
Future<List<LowStockProduct>> getCriticalItems({
  required String businessId,
})

// Get stock status with severity
StockStatus getStockStatus({
  required int quantity,
  required int threshold,
})

// Stream real-time updates
Stream<List<LowStockProduct>> streamLowStockProducts({
  required String businessId,
  int threshold = 10,
})

// Get statistics summary
Future<LowStockSummary> getLowStockSummary({
  required String businessId,
  int threshold = 10,
})

// Check multiple products at once
Future<Map<String, bool>> checkProductsLowStock({
  required String businessId,
  required List<String> productIds,
  int threshold = 10,
})
```

---

## 🎯 Next Steps

1. **Choose Your Pattern:**
   - Provider method for dashboard metrics
   - Unified service for detailed screens

2. **Implement Detection:**
   - Add method to provider or use service
   - Set default threshold (5-10 recommended)
   - Add sorting by quantity

3. **Display on Dashboard:**
   - Metric card showing count
   - Alert banner if items critical
   - Quick actions to view/reorder

4. **Link to Details Screen:**
   - Navigate to low_stock_products_screen
   - Pre-filter by category or supplier
   - Show recommended reorder quantities

5. **Add Notifications:**
   - Send alert when item goes critical (qty=0)
   - Send daily summary of low stock items
   - Include in email digests

---

## ✅ Summary

**Bar Dashboard Pattern:** ✅ In-memory, fast, real-time
**Unified Service Pattern:** ✅ Persistent, searchable, detailed

**Use both together:**
- Dashboard: Quick metrics using provider method
- Inventory Screen: Detailed management using service

**Files to Reference:**
- `lib/services/low_stock_detection_service.dart` - Main service
- `lib/presentation/inventory/screens/low_stock_products_screen_enhanced.dart` - Enhanced screen example
- `lib/presentation/industry_specific/drink/screens/drink_dashboard_screen.dart` - Bar dashboard pattern
- `LOW_STOCK_DETECTION_IMPLEMENTATION_GUIDE.md` - Detailed documentation
