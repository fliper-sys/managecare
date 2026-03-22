# Sales & Procurement Fetching - Quick Reference & Best Practices

## Three Screens Comparison Matrix

| Feature | Export Sales History | Procurement History | Product Details (Sales) | Product Details (Procurement) |
|---------|----------------------|---------------------|-------------------------|------------------------------|
| **Purpose** | Export all business sales | View all procurements | View product sales only | View product procurements only |
| **Data Scope** | 1000+ sales | All procurements | 10-20 sales for product | 10 procurements for product |
| **Query Type** | One-time fetch | Real-time stream | Real-time stream | Real-time stream |
| **Collection** | Nested + Root both | Nested only | Nested | Nested |
| **Date Filtering** | Server-side WHERE | Local filtering | ❌ NOT IMPLEMENTED | ❌ NOT IMPLEMENTED |
| **Product Filtering** | By search text | Manual filter | ❌ BROKEN (arrayContains) | ❌ NOT FILTERING |
| **Timestamp Field** | `createdAt` ✓ | `createdAt` ✓ | `timestamp` ❌ | `timestamp` ❌ |
| **Cost Calculation** | Full sale amount | Full procurement | N/A | ❌ All items cost |
| **Quantity Extraction** | From items array | From items array | ❌ Never reached | ❌ Not extracted |
| **Search Support** | 5+ fields | 2 fields | By items only | None |
| **Real-time Updates** | No | Yes | Yes | Yes |
| **Performance** | Good (indexed) | Good (stream) | Poor (no index) | Poor (fetches all) |

---

## Correct Implementation Pattern

### Pattern 1: Export/Report (Fetch Model)
```dart
// USE: When you need to export/report historical data
// EXAMPLE: Export Sales History screen

Future<List<Map<String, dynamic>>> fetchData({
  String? businessId,
  DateTime? start,
  DateTime? end,
  String? search,
  int limit = 1000,
}) async {
  // Step 1: Query with date range & limits
  Query query = _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('sales')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
      .orderBy('createdAt', descending: true)
      .limit(limit);
  
  var snapshot = await query.get();
  
  // Step 2: Combine multiple data sources if needed
  // (nested + root collections, different timestamp fields, etc.)
  
  // Step 3: Deduplicate
  
  // Step 4: Client-side search filtering (after fetch)
  if (search != null) {
    // Filter for search term
  }
  
  // Step 5: Return processed list
  return list;
}
```

**Best for:**
- Export/reporting screens
- One-time data retrieval
- Large datasets
- Complex filtering needs

---

### Pattern 2: Real-Time List (Stream Model)
```dart
// USE: For real-time updates of data
// EXAMPLE: Procurement History screen

StreamBuilder<QuerySnapshot>(
  stream: _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('procurements')
      .orderBy('createdAt', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    // Step 1: Apply client-side filters on snapshot
    var filtered = snapshot.data?.docs.where((doc) {
      // Date range filter
      // Search filter
      // Product filter
    }).toList() ?? [];
    
    // Step 2: Sort/group if needed
    
    // Step 3: Build UI from filtered list
  }
)
```

**Best for:**
- Live-updating lists
- Dashboard views
- Small-medium datasets
- Simple filtering

---

### Pattern 3: Product-Specific Analytics (Mixed Model)
```dart
// USE: For product-specific data like Product Details screen
// HYBRID: Real-time stream + client-side filtering

StreamBuilder<QuerySnapshot>(
  stream: _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('sales')
      .orderBy('createdAt', descending: true)  // Up-to-date
      .limit(100)  // Fetch enough to filter
      .snapshots(),
  builder: (context, snapshot) {
    // Step 1: Filter for this product ONLY
    var forThisProduct = snapshot.data?.docs.where((doc) {
      final items = (doc['items'] as List?) ?? [];
      return items.any((item) => 
        item is Map && item['productId'] == thisProductId
      );
    }).toList() ?? [];
    
    // Step 2: Apply date range if selected
    var inDateRange = forThisProduct.where((doc) {
      final timestamp = _parseTimestamp(doc['createdAt']);
      return _dateRange == null || 
             (!timestamp.isBefore(_dateRange!.start) &&
              !timestamp.isAfter(_dateRange!.end));
    }).toList();
    
    // Step 3: Extract product-specific data
    var stats = _calculateProductStats(inDateRange, thisProductId);
    
    // Step 4: Build UI
  }
)
```

**Best for:**
- Product-level details
- Analytics requiring drill-down
- Real-time + filtered data
- Mixed source data (product + sales/procurement)

---

## Field Standards

### Timestamp Fields
```dart
// STANDARD: Use 'createdAt' as primary timestamp
{
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
}

// LEGACY: Support 'timestamp' for backcompat
{
  timestamp: DateTime.now().millisecondsSinceEpoch,  // Numeric milliseconds
}

// PARSING HELPER (Required)
DateTime parseTimestamp(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
```

### Items Array Structure
```dart
// STANDARD: Items array in sales/procurements
{
  items: [
    {
      productId: "prod123",      // REQUIRED: For filtering/referencing
      productName: "Widget",     // Optional: For display
      quantity: 5,               // REQUIRED: For calculations
      unitPrice: 100,            // For sales
      unitCost: 50,              // For procurements  
      total: 500,                // quantity * price
    }
  ],
  productIds: ["prod123"],       // OPTIONAL: For efficient querying
}
```

### For Efficient Querying - Add Index Fields
```dart
// RECOMMENDED ADDITIONS for query efficiency:
{
  items: [...],
  productIds: ["prod123", "prod456"],  // Enables: .where('productIds', arrayContains: id)
  createdAt: Timestamp,
  businessId: "biz123",                // For root collection queries
  status: "completed",                 // For status queries
}
```

---

## Common Filtering Patterns

### Filter 1: By Date Range
```dart
// Server-side (Efficient)
query = query
    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
    .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

// Client-side (When needed)
filtered = docs.where((doc) {
  final timestamp = parseTimestamp(doc['createdAt']);
  return !timestamp.isBefore(start) && !timestamp.isAfter(end);
}).toList();
```

### Filter 2: By Product ID
```dart
// With productIds array (Best - requires db structure change)
.where('productIds', arrayContains: productId)

// Without productIds (Client-side)
filtered = docs.where((doc) {
  final items = (doc['items'] as List?) ?? [];
  return items.any((item) => 
    item is Map && (item['productId'] == productId || item['product_id'] == productId)
  );
}).toList();
```

### Filter 3: By Search Text
```dart
filtered = docs.where((doc) {
  final searchLower = query.toLowerCase();
  final data = doc.data() as Map<String, dynamic>;
  
  // Check multiple fields
  return (data['customerName'] ?? '').toString().toLowerCase().contains(searchLower) ||
         (data['invoiceRef'] ?? '').toString().toLowerCase().contains(searchLower) ||
         doc.id.toLowerCase().contains(searchLower);
}).toList();
```

### Filter 4: By Status
```dart
// Server-side
.where('status', isEqualTo: 'received')

// Client-side
filtered = docs.where((doc) => doc['status'] == 'received').toList();
```

---

## Cost Calculation Patterns

### Pattern A: Full Transaction Cost
```dart
// Use when showing total transaction amount
final totalCost = (doc['totalCost'] ?? doc['total'] ?? 0) as num;
```

### Pattern B: Product-Specific Cost in Mixed Transaction
```dart
// Use when showing cost of ONE PRODUCT in multi-product transaction
final items = (doc['items'] as List?) ?? [];
final productItem = items.firstWhere(
  (item) => item is Map && item['productId'] == targetProductId,
  orElse: () => null,
);

// Option 1: Item has 'total' field
final itemCost = (productItem?['total'] ?? 0) as num;

// Option 2: Calculate from quantity and unitCost
final qty = (productItem?['quantity'] ?? 0) as num;
final unitCost = (productItem?['unitCost'] ?? 0) as num;
final itemCost = qty * unitCost;
```

### Pattern C: Margin Calculation
```dart
// Simple percentage
final percentage = ((sellingPrice - costPrice) / sellingPrice) * 100;

// For multiple items
int totalUnits = 0;
double totalRevenue = 0.0;
double totalCost = 0.0;

for (var item in items) {
  final qty = item['quantity'] as num;
  final price = item['unitPrice'] as num;
  final cost = item['unitCost'] as num;
  
  totalUnits += qty.toInt();
  totalRevenue += qty * price;
  totalCost += qty * cost;
}

final margin = ((totalRevenue - totalCost) / totalRevenue) * 100;
```

---

## Performance Optimization Tips

### 1. Use Indexes for Common Queries
```
Index: businesses/{businessId}/sales
Fields: createdAt (Descending), businessId

Index: businesses/{businessId}/procurements  
Fields: createdAt (Descending), status (Ascending)

Index for product queries (if adding productIds):
Fields: productIds (Arrays), createdAt (Descending)
```

### 2. Limit Query Results
```dart
// Always limit on server side
.limit(100)  // Then filter client-side if needed

// For streams, increasing limit = more data + more updates
.limit(20)   // Conservative for frequent updates
.limit(100)  // Moderate for detailed views
.limit(500)  // Large for analytics
```

### 3. Cache Timestamp Parsing
```dart
// Instead of parsing every time:
final timestamp = parseTimestamp(doc['createdAt']);  // DO THIS
// Not: DateFormat(...).format(parseTimestamp(doc['createdAt']))

// Cache formatted dates:
final formattedDate = DateFormat('MMM dd').format(timestamp);
```

### 4. Batch Similar Filtering
```dart
// DO: Filter everything at once
final filtered = docs
  .where((d) => matchesProduct(d))
  .where((d) => matchesDateRange(d))
  .where((d) => matchesSearch(d))
  .toList();

// DON'T: Filter in separate passes
final byProduct = docs.where((d) => matchesProduct(d)).toList();
final byDate = byProduct.where((d) => matchesDateRange(d)).toList();
final bySearch = byDate.where((d) => matchesSearch(d)).toList();
```

### 5. Use Composite Indexes for Complex Queries
```dart
// This needs a composite index:
.where('businessId', isEqualTo: bid)
.where('createdAt', isGreaterThanOrEqualTo: start)
.where('createdAt', isLessThanOrEqualTo: end)
.orderBy('createdAt', descending: true)

// Create in Firestore:
Collection: sales
Fields: businessId (Ascending), createdAt (Descending)
```

---

## Migration Checklist for Product Details

If you implement the fixes, follow this order:

- [ ] **Phase 1: Add Helper Methods**
  - [ ] `DateTime _parseTimestamp(dynamic value)`
  - [ ] `int _extractProductQuantityFromSale(Map data)`
  - [ ] `_calculateProductCostInTransaction(Map item)`

- [ ] **Phase 2: Fix Timestamp Usage**
  - [ ] Change all queries to use `createdAt`
  - [ ] Update all parsing to use helper method
  - [ ] Test with existing data

- [ ] **Phase 3: Fix Sales Tab**
  - [ ] Update query to not use `arrayContains`
  - [ ] Add product filtering logic
  - [ ] Apply date range widget
  - [ ] Test with product that has sales

- [ ] **Phase 4: Fix Procurement Tab**
  - [ ] Add product filtering logic
  - [ ] Update cost calculations
  - [ ] Test with product in procurements

- [ ] **Phase 5: Standardize Stats Calculation**
  - [ ] `_calculateSalesStats()` - use filtered data
  - [ ] `_calculateProcurementStats()` - product-specific cost
  - [ ] Test accuracy of results

- [ ] **Phase 6: Testing & Validation**
  - [ ] Test with product having multiple sales
  - [ ] Test with product in multiple procurements
  - [ ] Test date range filters work
  - [ ] Test with no records scenario
  - [ ] Test legacy data with `timestamp` field

---

## Firestore Document Examples

### Sales Document Structure (Correct)
```json
{
  "id": "sale_001",
  "businessId": "biz_123",
  "createdAt": "2024-02-12T14:30:00Z",  // Use Timestamp
  "timestamp": 1707756600000,            // Keep for legacy compat
  "customerName": "John Doe",
  "paymentMethod": "cash",
  "items": [
    {
      "productId": "prod_001",
      "productName": "Widget",
      "quantity": 5,
      "unitPrice": 1000,
      "total": 5000
    },
    {
      "productId": "prod_002", 
      "productName": "Gadget",
      "quantity": 2,
      "unitPrice": 2000,
      "total": 4000
    }
  ],
  "productIds": ["prod_001", "prod_002"],  // For efficient queries
  "totalAmount": 9000,
  "finalAmount": 9000
}
```

### Procurement Document Structure (Correct)
```json
{
  "id": "proc_001",
  "businessId": "biz_123",
  "createdAt": "2024-02-12T10:00:00Z",  // Use Timestamp
  "timestamp": 1707739200000,            // Keep for legacy compat
  "supplierName": "Wholesaler Inc",
  "invoiceRef": "INV-001",
  "items": [
    {
      "productId": "prod_001",
      "name": "Widget",
      "quantity": 100,
      "unitCost": 500,
      "total": 50000
    }
  ],
  "productIds": ["prod_001"],           // For efficient queries  
  "totalCost": 50000,
  "status": "received"
}
```

---

## Common Mistakes to Avoid

❌ **DON'T:**
1. Use `arrayContains` with nested object properties
2. Query by timestamp without converting types
3. Calculate stats on ALL records instead of filtered
4. Mix `createdAt` and `timestamp` without conversion
5. Fetch unlimited records then filter
6. Show stats that don't match filtered display

✓ **DO:**
1. Filter for product BEFORE calculating stats
2. Use consistent date/time fields
3. Parse timestamps with helper method
4. Apply server-side filters first
5. Extract product-specific data from items
6. Test with edge cases (no records, legacy data)

