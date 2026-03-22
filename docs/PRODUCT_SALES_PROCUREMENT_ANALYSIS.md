# Product Sales & Procurement Record Fetching Analysis

## Executive Summary
Analysis of how sales and procurement records are fetched in Export Sales History, Procurement History screens, and the Product Details screen to ensure consistency and appropriate filtering.

---

## 1. Export Sales History Screen (`export_sales_history_screen.dart`)

### How Sales Records Are Fetched

**Method:** `ReportsProvider.fetchSalesList()`

```dart
Future<List<Map<String, dynamic>>> fetchSalesList({
  String? businessId,
  DateTime? start,
  DateTime? end,
  String? search,
  int limit = 1000,
})
```

### Data Sources
1. **Nested Query (Primary)**
   - Collection: `businesses/{businessId}/sales`
   - Filters: `createdAt` timestamp range with date constraints
   - Sort: By `createdAt` descending
   - Limit: Configurable (default 1000)

2. **Root Query (Fallback)**
   - Collection: `sales`
   - Filters: `businessId` equality + timestamp range
   - Sort: By `createdAt` descending
   - Limit: Configurable (default 1000)

### Deduplication & Merging
- Combines results from both queries
- Nested docs take precedence over root docs
- Sorts by `createdAt` field (supports multiple date formats)

### Search Filtering
Searches across:
- Receipt/Sale ID
- Customer name (`customerName`, `customerDisplayName`, `customer`)
- Payment method (`paymentMethod`, `payment`)
- Cashier/Worker (`cashier`, `workerName`, `soldBy`)
- Product names in items array

### Date Filtering
- Uses Firestore WHERE clauses for server-side filtering
- Supports Firestore Timestamp objects
- Falls back to numeric `timestamp` field if needed
- Has composite index requirement for optimal performance

### Key Points ✓
- Filters happen at **database query level** (efficient)
- Supports both `createdAt` and `timestamp` fields
- Proper handling of multiple date formats
- Comprehensive search across multiple fields

---

## 2. Procurement History Screen (`procurement_history_screen.dart`)

### How Procurement Records Are Fetched

**Method:** `ProcurementRepository.procurementsStream()`

```dart
stream: ProcurementRepository().procurementsStream(businessId: businessId)
```

### Data Source
- Collection: `businesses/{businessId}/procurements`
- Query: Ordered by `createdAt` descending in real-time stream

### Filtering Approach
**Local (Client-Side) Filtering:**
```dart
final filtered = docs.where((d) {
  final searchText = _searchController.text.toLowerCase();
  final createdAt = parseTimestamp(d['createdAt'] ?? DateTime.now());
  final dateOk = _range == null || (!createdAt.isBefore(_range!.start) && !createdAt.isAfter(_range!.end));
  final items = (d['items'] as List?)?.cast<dynamic>() ?? [];
  final itemsMatch = items.any((it) => (it['name'] ?? '').toString().toLowerCase().contains(searchText));
  final idMatch = d.id.toLowerCase().contains(searchText);
  return dateOk && (searchText.isEmpty || itemsMatch || idMatch);
}).toList();
```

### Key Points ✓
- Real-time stream for live updates
- Local filtering for search and date range
- Groups records by day
- Supports PDF/CSV export

---

## 3. Product Details Screen - Currently Issues ⚠️

### Sales History Tab Problems

#### Issue 1: Incorrect Product Filtering
```dart
// CURRENT (WRONG):
stream: FirebaseFirestore.instance
    .collection('businesses')
    .doc(businessId)
    .collection('sales')
    .where('items', arrayContains: widget.productId)  // ❌ WRONG
```

**Problem:** 
- `arrayContains` checks if `items` array contains the exact value `widget.productId`
- But `items` is an array of objects/maps like: `[{productId: "xyz", quantity: 5}, ...]`
- This query will NOT match anything!

**Solution:**
- Need to query ALL sales and filter locally, OR
- Store a separate `productIds` array in each sale for easier querying

#### Issue 2: Date Range Not Applied
```dart
// CURRENT:
_dateRange = DateTimeRange(
  start: now.subtract(const Duration(days: 30)),
  end: now,
);
```
- Date picker exists and stores range
- But the `StreamBuilder` query does NOT use `_dateRange`
- All sales are fetched regardless of date selection

#### Issue 3: Incorrect Timestamp Field
```dart
// CURRENT:
.where('items', arrayContains: widget.productId)
.orderBy('timestamp', descending: true)  // Using 'timestamp' not 'createdAt'
```
- Export Sales History uses `createdAt`
- Product Details uses `timestamp`
- Inconsistency and potential missing data

#### Issue 4: Product Quantity Not Extracted Properly
```dart
// In _calculateSalesStats - trying to find product in items:
for (var item in items) {
  if (item is Map && item['productId'] == widget.productId) {
    totalUnits += (item['quantity'] as num?)?.toInt() ?? 0;
  }
}
```
- This logic would work IF the arrayContains query worked
- But since query is broken, this is never reached properly

---

### Procurement History Tab Problems

#### Issue 1: No Product Filtering
```dart
// CURRENT (NO FILTERING):
stream: FirebaseFirestore.instance
    .collection('businesses')
    .doc(Provider.of<BusinessProvider>...) 
    .collection('procurements')
    .orderBy('timestamp', descending: true)
    .limit(10)
    .snapshots(),
```

**Problem:**
- Shows ALL procurements in the business
- NOT filtered for this specific product
- Should show only procurements containing this product

#### Issue 2: Timestamp Field Inconsistency
- Uses `timestamp` instead of `createdAt`
- Different from Export Sales History screen

#### Issue 3: Stats Not Product-Specific
```dart
// In _calculateProcurementStats:
for (var doc in snapshot.docs) {  // Gets ALL procurements
  totalCost += (data['totalCost'] as num?)?.toDouble() ?? 0.0;  // Adds ALL costs
  // But then filters by productId for items only
  for (var item in items) {
    if (item is Map && item['productId'] == widget.productId) {
      totalUnits += (item['quantity'] as num?)?.toInt() ?? 0;
    }
  }
}
```
- `totalCost` includes cost of entire procurement (all products)
- Should only include cost of this product's portion

---

## 4. Recommended Improvements

### A. Sales History Tab - Fixes Needed

**1. Fix Query (Choose One)**

Option A - Fetch all and filter locally (Less efficient but simpler):
```dart
stream: FirebaseFirestore.instance
    .collection('businesses')
    .doc(businessId)
    .collection('sales')
    .orderBy('createdAt', descending: true)  // Use createdAt
    .limit(100)  // Limit client-side
    .snapshots(),
// Then filter locally for this product
```

Option B - Store productIds array for efficient querying:
```dart
// In Firestore document structure:
{
  items: [{productId: "xyz", quantity: 5}],
  productIds: ["xyz", ...],  // Add this field
  createdAt: Timestamp
}

// Then query:
.where('productIds', arrayContains: widget.productId)
.where('createdAt', isGreaterThanOrEqualTo: _dateRange!.start)
.where('createdAt', isLessThanOrEqualTo: _dateRange!.end)
```

**2. Apply Date Range Filtering**
```dart
if (_dateRange != null) {
  query = query
    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start))
    .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end));
}
```

**3. Use Consistent Timestamp Field**
- Change all to use `createdAt` instead of `timestamp`

**4. Extract Product Quantity Correctly**
```dart
// After querying, extract quantity:
final items = saleData['items'] as List? ?? [];
final productItem = items.firstWhere(
  (item) => item is Map && item['productId'] == widget.productId,
  orElse: () => null,
);
final quantity = (productItem?['quantity'] as num?)?.toInt() ?? 0;
```

---

### B. Procurement History Tab - Fixes Needed

**1. Filter for This Product Only**
```dart
// Option: Local filtering after fetch
.snapshots()
.map((snapshot) {
  return snapshot.docs.where((doc) {
    final items = (doc['items'] as List?) ?? [];
    return items.any((item) => 
      item is Map && item['productId'] == widget.productId
    );
  }).toList();
})
```

**2. Use Consistent Timestamp Field**
- Change `timestamp` to `createdAt`

**3. Calculate Product Cost Portion**
```dart
// In _calculateProcurementStats:
for (var doc in snapshot.docs) {
  final data = doc.data();
  final items = data['items'] as List?;
  if (items != null) {
    for (var item in items) {
      if (item is Map && item['productId'] == widget.productId) {
        totalUnits += (item['quantity'] as num?)?.toInt() ?? 0;
        // Only add this item's cost, not entire procurement cost
        totalCost += (item['cost'] ?? 0) as num;
      }
    }
  }
}
```

---

## 5. Data Structure Consistency

### Recommended Firestore Structure
```
businesses/{businessId}/sales/{saleId}
{
  createdAt: Timestamp,
  finals: {sales total amount},
  items: [
    {
      productId: "prod123",
      productName: "Product Name",
      quantity: 5,
      unitPrice: 1000,
      total: 5000
    }
  ],
  productIds: ["prod123", ...],  // For efficient queries
  customerName: "...",
  paymentMethod: "cash",
  ...
}

businesses/{businessId}/procurements/{procId}
{
  createdAt: Timestamp,
  supplierName: "...",
  invoiceRef: "...",
  items: [
    {
      productId: "prod123",
      name: "Product Name",
      quantity: 100,
      unitCost: 500,
      total: 50000
    }
  ],
  productIds: ["prod123", ...],  // For efficient queries
  totalCost: 50000,  // Sum of all items
  status: "received",
  ...
}
```

---

## 6. Pattern Consistency Summary

| Aspect | Export Sales | Procurement | Product Details (Sales) | Product Details (Procurement) |
|--------|--------------|-------------|------------------------|------------------------------|
| **Data Source** | Nested + Root | Nested only | Nested | Nested |
| **Timestamp Field** | `createdAt` | `createdAt` | `timestamp` ❌ | `timestamp` ❌ |
| **Product Filtering** | By items search | Manual filter | `arrayContains` ❌ | None ❌ |
| **Date Filtering** | WHERE clause | Local filter | Not applied ❌ | Not applied ❌ |
| **Search Fields** | 5 fields | 2 fields | By items only | None |
| **Real-time** | No (fetch) | Yes (stream) | Yes (stream) | Yes (stream) |
| **Cost Breakdown** | Full sale | Full procurement | Not extracted ❌ | All items ❌ |

---

## 7. Recommendations Priority

### High Priority (Must Fix)
1. ✅ Fix sales query - `arrayContains` not working for nested objects
2. ✅ Apply date range filter in sales query
3. ✅ Standardize to `createdAt` field everywhere
4. ✅ Filter procurement history for this product only
5. ✅ Calculate product-specific costs in procurement

### Medium Priority (Should Fix)
6. Follow Export Sales History pattern for consistency
7. Extract product quantity correctly
8. Apply cost breakdown logic

### Low Priority (Nice to Have)
9. Add search functionality to product sales/procurement
10. Add more detailed stats beyond basic totals

---

## 8. Implementation Path

1. **Phase 1:** Create helper methods in Product Details screen similar to Export Sales
2. **Phase 2:** Fix product filtering logic for both tabs
3. **Phase 3:** Apply date range filtering properly
4. **Phase 4:** Standardize timestamp field usage
5. **Phase 5:** Extract costs correctly for procurement

