# Low Stock Detection Implementation Guide

## Overview
This guide explains how low stock product detection is properly implemented across the application, specifically comparing the **Bar Dashboard** approach with the **Low Stock Products Screen**.

---

## 🎯 Two Implementation Patterns

### Pattern 1: Provider-Based Detection (Bar Dashboard)
**File:** `lib/presentation/industry_specific/drink/screens/drink_dashboard_screen.dart`  
**Provider:** `DrinkProvider`

#### Method: `getLowStockDrinks()`
```dart
List<DrinkItem> getLowStockDrinks([int threshold = 6]) {
  return drinks.where((d) => getTotalBottles(d.id) <= threshold).toList();
}
```

**Characteristics:**
- ✅ **In-memory filtering** using provider's cached data
- ✅ **Configurable threshold** (default: 6 bottles)
- ✅ **Real-time updates** when provider notifies listeners
- ✅ **Dependency on TotalBottles calculation** accounting for bottles + cartons
- ✅ **Used for:** Metrics display, quick stock overview on dashboard
- ✅ **Performance:** O(n) where n = number of drinks
- ✅ **Freshness:** Only as fresh as last provider update

**Integration in Dashboard:**
```dart
final lowStock = drinkProvider.getLowStockDrinks();

// Display as metric card
_buildStatCard(
  icon: '⚠️',
  label: 'Low Stock Items',
  value: '${lowStock.length}',
  color: AppColors.warning,
)

// Stock Overview shows visual indicators
final isLow = getTotalBottles(drink.id) <= 6;
// Display red/orange badge if isLow
```

---

### Pattern 2: Firestore Query + Client-Side Filtering (Low Stock Screen)
**File:** `lib/presentation/inventory/screens/low_stock_products_screen.dart`

#### Method: `_fetchLowStockProducts()`
```dart
Future<List<Map<String, dynamic>>> _fetchLowStockProducts() async {
  try {
    final businessProvider = context.read<BusinessProvider>();
    final business = businessProvider.currentBusiness;

    if (business == null) {
      throw Exception('No business selected');
    }

    final businessId = business.id;
    final threshold = _minStockThreshold; // Configurable: 1-100
    
    // Fetch ALL products from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('products')
        .get();

    // Client-side filtering to avoid composite index requirement
    final lowStockProducts = snapshot.docs
        .where((doc) {
          final qty = (doc['quantity'] as num?)?.toInt() ?? 0;
          return qty <= threshold;  // Main detection logic
        })
        .toList()
        ..sort((a, b) {
          final aQty = (a['quantity'] as num?)?.toInt() ?? 0;
          final bQty = (b['quantity'] as num?)?.toInt() ?? 0;
          return aQty.compareTo(bQty);  // Sort: lowest stock first
        });

    return lowStockProducts.map((doc) => {
          'id': doc.id,
          'name': doc['name'] ?? 'Unknown',
          'quantity': doc['quantity'] ?? 0,
          'unit': doc['unit'] ?? 'units',
          'reorderLevel': doc['reorderLevel'] ?? threshold,
          'costPrice': doc['costPrice'] ?? 0.0,
          'sellingPrice': doc['sellingPrice'] ?? 0.0,
          'category': doc['category'] ?? 'General',
          'supplier': doc['supplier'] ?? 'Not specified',
          'lastRestocked': doc['lastRestocked'] as Timestamp?,
        }).toList();
  } catch (e) {
    print('[LowStockScreen] Error fetching products: $e');
    rethrow;
  }
}
```

**Characteristics:**
- ✅ **Firestore integration** for persistent data
- ✅ **Dynamic threshold adjustment** via slider (1-100 units)
- ✅ **Client-side filtering** to avoid composite Firestore indexes
- ✅ **Automatic sorting** by quantity ascending (critical items first)
- ✅ **Comprehensive data** including cost, supplier, reorder levels
- ✅ **Refresh capability** for manual data reload
- ✅ **Used for:** Detailed inventory management, procurement decisions
- ✅ **Performance:** Depends on total products (fewer, better)
- ✅ **Freshness:** Always pulls latest from Firestore

**Threshold Configuration:**
```dart
class _LowStockProductsScreenState extends State<LowStockProductsScreen> {
  int _minStockThreshold = 10;  // Default: 10 units

  void _updateThreshold(int newThreshold) {
    setState(() {
      _minStockThreshold = newThreshold;
      _loadLowStockProducts();
    });
  }
}
```

**UI Threshold Control:**
```dart
Slider(
  value: _minStockThreshold.toDouble(),
  min: 1,
  max: 100,
  divisions: 99,
  label: '$_minStockThreshold units',
  onChanged: (value) {
    _updateThreshold(value.toInt());
  },
)
```

---

## 📊 Comparison Matrix

| Aspect | Bar Dashboard | Low Stock Screen |
|--------|---------------|------------------|
| **Data Source** | Provider (in-memory) | Firestore (persistent) |
| **Detection Logic** | `getTotalBottles() <= 6` | `quantity <= threshold` |
| **Threshold** | Fixed: 6 bottles | Dynamic: 1-100 units |
| **Filtering** | In-memory (provider) | Client-side + Firestore |
| **Sorting** | None (unsorted) | By quantity ascending |
| **Update Frequency** | Real-time (listener) | Manual refresh or interval |
| **Use Case** | Quick dashboard metric | Detailed inventory review |
| **Performance** | Fast (O(n) in-memory) | Slower (network + Firestore) |
| **Freshness** | Good (provider cache) | Best (live Firestore) |
| **Business Types** | Drink/Bar specific | All business types |

---

## 🔧 How to Implement for Other Dashboards

### Step 1: Choose Your Detection Method

**Use Provider Method If:**
- You have a provider with cached products
- You need real-time updates
- Threshold is fixed or rarely changes
- Dashboard-specific logic (Barber, Salon, etc.)

**Use Firestore Method If:**
- You need persistent, searchable data
- Threshold must be user-configurable
- Need comprehensive product details
- Dedicated inventory management screen

### Step 2: Implement Detection Logic

**For Provider-Based (Similar to Bar Dashboard):**
```dart
// In your provider (e.g., SalonProvider)
List<Product> getLowStockProducts([int threshold = 5]) {
  return products
      .where((p) => p.quantity <= threshold)
      .toList();
}
```

**For Firestore-Based (Like Low Stock Screen):**
```dart
Future<List<Map<String, dynamic>>> fetchLowStockProducts(
    String businessId, {int threshold = 10}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('businesses')
      .doc(businessId)
      .collection('products')
      .get();

  return snapshot.docs
      .where((doc) {
        final qty = (doc['quantity'] as num?)?.toInt() ?? 0;
        return qty <= threshold;
      })
      .toList()
      ..sort((a, b) {
        final aQty = (a['quantity'] as num?)?.toInt() ?? 0;
        final bQty = (b['quantity'] as num?)?.toInt() ?? 0;
        return aQty.compareTo(bQty);
      });
}
```

### Step 3: Display on Dashboard

**As Metric Card:**
```dart
_buildStatCard(
  icon: '⚠️',
  label: 'Low Stock',
  value: '${lowStockItems.length}',
  color: Colors.orange,
)
```

**As Alert Banner:**
```dart
if (lowStockItems.isNotEmpty)
  Container(
    color: Colors.orange[100],
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        const Icon(Icons.warning_amber, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${lowStockItems.length} items running low',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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
  )
```

### Step 4: Link to Detailed Screen

```dart
// From dashboard quick action or alert
onPressed: () => Navigator.pushNamed(
  context,
  Routes.lowStockProducts,
)
```

---

## 📋 Complete Implementation Checklist

- [ ] **Choose detection method** (Provider vs Firestore)
- [ ] **Implement detection logic** in provider or screen
- [ ] **Add configurable threshold** if needed
- [ ] **Implement sorting** (by quantity ascending)
- [ ] **Add visual indicators** (colors: red/orange/blue)
- [ ] **Display on dashboard** (metric card or banner)
- [ ] **Add refresh capability** (manual button)
- [ ] **Implement error handling** with retry
- [ ] **Add empty state** when no low stock items
- [ ] **Test with different thresholds** (1, 10, 50, 100)
- [ ] **Verify Firestore query** works without index
- [ ] **Check performance** with large product lists
- [ ] **Add notifications** for critical stock levels
- [ ] **Document threshold values** for team

---

## 🎨 Color Coding Standards

```dart
// Stock status colors
Color getStockStatusColor(int quantity, int threshold) {
  if (quantity == 0) {
    return Colors.red;  // Out of stock: RED
  } else if (quantity <= threshold * 0.33) {
    return Colors.red;  // Critical: RED
  } else if (quantity <= threshold) {
    return Colors.orange;  // Low: ORANGE
  } else {
    return Colors.green;  // Normal: GREEN
  }
}
```

---

## 🚀 Performance Considerations

### Bar Dashboard (Provider)
- **No network calls**: Uses in-memory data
- **Instant updates**: Real-time listener notifications
- **Scalability**: Limited to drinks/items in provider
- **Best for**: Quick dashboard metrics

### Low Stock Screen (Firestore)
- **Network overhead**: Fetches from Firestore
- **Slight delay**: Async operation required
- **Scalability**: Can handle large product catalogs
- **Optimization**: Consider pagination for 1000+ products

---

## 📱 Example: Barber Shop Dashboard Integration

```dart
// In barber_shop_dashboard_screen.dart
class _BarberDashboardState extends State<BarberShopDashboard> {
  @override
  Widget build(BuildContext context) {
    return Consumer<BarberShopProvider>(
      builder: (context, provider, _) {
        final lowStockItems = provider.getLowStockProducts(threshold: 5);
        
        return SingleChildScrollView(
          child: Column(
            children: [
              // Existing metric cards...
              
              // Add Low Stock Metric
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
              
              // Low stock alert if any items are critical
              if (lowStockItems.isNotEmpty)
                _buildLowStockAlert(lowStockItems),
            ],
          ),
        );
      },
    );
  }
}
```

---

## ✅ Summary

**Bar Dashboard Approach:**
- Use for: Quick metrics on dashboard
- Detection: In-memory provider filtering
- Threshold: Fixed or rarely changing
- Best for: Specific business types with dedicated providers

**Low Stock Products Screen Approach:**
- Use for: Detailed inventory management
- Detection: Firestore + client-side filtering
- Threshold: User-configurable
- Best for: Cross-business inventory operations

**Recommendation:** Implement both patterns:
1. **Dashboard**: Use provider method for quick metrics
2. **Inventory Screen**: Use Firestore method for detailed management
