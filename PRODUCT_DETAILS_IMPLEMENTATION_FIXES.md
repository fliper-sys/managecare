# Product Details Screen - Specific Implementation Fixes

## Overview
This document provides specific code implementations to fix the sales and procurement record fetching in the Product Details screen to match the efficiency and accuracy of the Export Sales History screen.

---

## Issue #1: Sales Query Using `arrayContains` on Nested Objects ❌

### Current Problem
```dart
// WRONG - productId is not a direct element of items array
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('businesses')
      .doc(businessId)
      .collection('sales')
      .where('items', arrayContains: widget.productId)  // BUG: items is array of objects
      .orderBy('timestamp', descending: true)
      .limit(10)
      .snapshots(),
```

### Why It Fails
- `items` array contains objects like `{productId: "xyz", quantity: 5}`
- `arrayContains: widget.productId` looks for exact match of productId as element
- Query returns no results

### Solution 1: Add `productIds` Array to Sales Document (Best)
**Profile:** Requires changing how sales are created/stored

If each sale document had:
```dart
{
  items: [{productId: "prod123", quantity: 5}],
  productIds: ["prod123"],  // Add this
  createdAt: Timestamp,
}
```

Then query becomes simple and efficient:
```dart
.where('productIds', arrayContains: widget.productId)
.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start))
.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_dateRange!.end))
```

### Solution 2: Fetch All and Filter Locally (Quick Fix)
```dart
// Fetch all sales without filtering by product
// Filter on client side for product match
stream: FirebaseFirestore.instance
    .collection('businesses')
    .doc(businessId)
    .collection('sales')
    .orderBy('createdAt', descending: true)  // Use createdAt not timestamp
    .limit(100)  // Fetch more since we'll filter
    .snapshots(),
builder: (context, snapshot) {
  if (!snapshot.hasData) return LoadingIndicator();
  
  // Filter for sales containing this product
  final salesWithProduct = snapshot.data!.docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];
    return items.any((item) => 
      item is Map && item['productId'] == widget.productId
    );
  }).toList();
  
  // Apply date range filter
  final filtered = salesWithProduct.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = _parseTimestamp(data['createdAt'] ?? data['timestamp']);
    if (_dateRange == null) return true;
    return !timestamp.isBefore(_dateRange!.start) && 
           !timestamp.isAfter(_dateRange!.end);
  }).toList();
  
  // Build list
  return ListView.builder(
    itemCount: filtered.length,
    itemBuilder: (context, index) {
      // ... build list item
    },
  );
}
```

---

## Issue #2: Date Range Not Being Applied ⚠️

### Current Problem
- `_dateRange` is set but not used in the query
- All sales are fetched regardless of date picker selection

### Solution: Apply Date Range to Query
```dart
Widget _buildSalesHistoryList() {
  final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
  final businessId = businessProvider.currentBusiness?.id ?? '';
  
  // Build query dynamically based on date range
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('businesses')
      .doc(businessId)
      .collection('sales')
      .orderBy('createdAt', descending: true);  // Use 'createdAt'
  
  // Apply date range if selected
  if (_dateRange != null) {
    query = query
        .where('createdAt', 
          isGreaterThanOrEqualTo: Timestamp.fromDate(_dateRange!.start)
        )
        .where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(
            _dateRange!.end.add(const Duration(days: 1))
          )
        );
  }
  
  query = query.limit(20);
  
  return StreamBuilder<QuerySnapshot>(
    stream: query.snapshots(),
    builder: (context, snapshot) {
      // ... existing builder code
    },
  );
}
```

### Alternative: Local Date Filtering (If Query Layer Can't Support)
```dart
// After fetching records, filter locally
final filtered = snapshot.data!.docs.where((doc) {
  final data = doc.data() as Map<String, dynamic>;
  final timestamp = _parseTimestamp(data['createdAt'] ?? data['timestamp']);
  
  if (_dateRange == null) return true;
  
  return !timestamp.isBefore(_dateRange!.start) && 
         !timestamp.isAfter(_dateRange!.end);
}).toList();
```

---

## Issue #3: Timestamp Field Inconsistency

### Current Problem
- Export Sales History uses `createdAt` (Firestore Timestamp)
- Product Details uses `timestamp` (numeric milliseconds?)
- This causes data inconsistency

### Solution: Create Helper Function
```dart
DateTime _parseTimestamp(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed ?? DateTime.now();
  }
  return DateTime.now();
}
```

Then use consistently:
```dart
final timestamp = _parseTimestamp(saleData['createdAt'] ?? saleData['timestamp']);
```

---

## Issue #4: Product Quantity Not Extracted Correctly

### Current Problem
```dart
// This logic only executes if the broken query succeeds
for (var item in items) {
  if (item is Map && item['productId'] == widget.productId) {
    totalUnits += (item['quantity'] as num?)?.toInt() ?? 0;
  }
}
```

### Solution: Extract Quantity for Sales
```dart
int _extractProductQuantityFromSale(Map<String, dynamic> saleData) {
  final items = (saleData['items'] as List?) ?? [];
  int totalQty = 0;
  
  for (var item in items) {
    if (item is Map) {
      final itemProductId = item['productId'] ?? item['product_id'] ?? item['id'];
      if (itemProductId == widget.productId) {
        final qty = item['quantity'] ?? item['qty'] ?? item['quantitySold'] ?? 0;
        totalQty += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 0;
      }
    }
  }
  
  return totalQty;
}
```

---

## Issue #5: Procurement History Not Filtered by Product

### Current Problem
```dart
// Shows ALL procurements, not just for this product
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('businesses')
      .doc(...)
      .collection('procurements')
      .orderBy('timestamp', descending: true)
      .limit(10)
      .snapshots(),
```

### Solution: Filter for Product-Specific Procurements
```dart
Widget _buildProcurementHistoryTab(String businessId, Product product) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProcurementStats(),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Procurement History', style: AppTextStyles.heading5),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .collection('procurements')
                  // Use consistent 'createdAt' field
                  .orderBy('createdAt', descending: true)
                  .limit(50)  // Fetch more to filter client-side
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No procurement records'));
                }
                
                // FILTER FOR THIS PRODUCT ONLY
                final procurementsForProduct = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final items = (data['items'] as List?) ?? [];
                  
                  // Check if any item matches this product
                  return items.any((item) =>
                    item is Map && 
                    (item['productId'] == widget.productId || 
                     item['product_id'] == widget.productId)
                  );
                }).toList();
                
                if (procurementsForProduct.isEmpty) {
                  return const Center(child: Text('No procurements for this product'));
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: procurementsForProduct.length,
                  itemBuilder: (context, index) {
                    final procDoc = procurementsForProduct[index];
                    final procData = procDoc.data() as Map<String, dynamic>;
                    final timestamp = _parseTimestamp(procData['createdAt'] ?? procData['timestamp']);
                    final status = procData['status'] ?? 'pending';
                    
                    // Extract this product's details from the procurement
                    final items = (procData['items'] as List?) ?? [];
                    final productItem = items.firstWhere(
                      (item) => item is Map && item['productId'] == widget.productId,
                      orElse: () => null,
                    );
                    
                    if (productItem == null) return const SizedBox.shrink();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.inventory_2,
                                color: AppColors.success,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    procData['supplierName'] ?? 'Unknown Supplier',
                                    style: AppTextStyles.body2
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Invoice: ${procData['invoiceRef'] ?? procDoc.id.substring(0, 8)}',
                                    style: AppTextStyles.caption,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Qty: ${productItem['quantity'] ?? 0} units',
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Cost: ₦${(productItem['total'] ?? 0).toStringAsFixed(0)}',
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: status == 'received'
                                              ? AppColors.success.withOpacity(0.2)
                                              : Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: AppTextStyles.caption.copyWith(
                                            color: status == 'received'
                                                ? AppColors.success
                                                : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(timestamp),
                                    style: AppTextStyles.caption
                                        .copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    ),
  );
}
```

---

## Issue #6: Procurement Stats Calculate All Costs Instead of Product Portion

### Current Problem
```dart
// Calculates total cost of ENTIRE procurement, not just this product
totalCost += (data['totalCost'] as num?)?.toDouble() ?? 0.0;
```

### Solution: Calculate Product-Only Cost
```dart
Future<Map<String, dynamic>> _calculateProcurementStats(String businessId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('procurements')
        .get();
    
    int totalUnits = 0;
    double productOnlyCost = 0.0;
    int pending = 0;
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'pending') pending++;
      
      final items = data['items'] as List?;
      if (items != null) {
        for (var item in items) {
          if (item is Map) {
            final itemProductId = item['productId'] ?? item['product_id'];
            
            if (itemProductId == widget.productId) {
              // Extract quantity
              final qty = item['quantity'] ?? item['qty'] ?? 0;
              totalUnits += (qty is num) ? qty.toInt() : 
                           int.tryParse(qty.toString()) ?? 0;
              
              // Extract cost for THIS PRODUCT ONLY
              // Use item 'total' or 'cost', not the entire procurement cost
              final itemCost = item['total'] ?? 
                              (item['quantity'] * item['unitCost']) ?? 
                              0;
              productOnlyCost += (itemCost is num) ? 
                                itemCost.toDouble() : 
                                double.tryParse(itemCost.toString()) ?? 0.0;
            }
          }
        }
      }
    }
    
    return {
      'totalUnits': totalUnits,
      'totalCost': productOnlyCost,  // Product-specific cost
      'pending': pending,
    };
  } catch (e) {
    debugPrint('Error calculating procurement stats: $e');
    return {'totalUnits': 0, 'totalCost': 0.0, 'pending': 0};
  }
}
```

---

## Summary of Code Changes Required

### 1. Add Helper Method
```dart
DateTime _parseTimestamp(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed ?? DateTime.now();
  }
  return DateTime.now();
}

int _extractProductQuantityFromSale(Map<String, dynamic> saleData) {
  final items = (saleData['items'] as List?) ?? [];
  int totalQty = 0;
  for (var item in items) {
    if (item is Map) {
      final itemProductId = item['productId'] ?? item['product_id'];
      if (itemProductId == widget.productId) {
        final qty = item['quantity'] ?? 0;
        totalQty += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 0;
      }
    }
  }
  return totalQty;
}
```

### 2. Update `_buildSalesHistoryList()`
- Change query to use `createdAt`
- Add date range WHERE clauses or local filtering
- Add product filtering logic
- Extract quantity correctly

### 3. Update `_buildProcurementHistoryTab()`
- Add product filtering logic
- Use consistent `createdAt` field
- Show product-specific details only

### 4. Update `_calculateSalesStats()`
- Fix to work with unpacked filtered results
- Use helper method for quantity extraction

### 5. Update `_calculateProcurementStats()`
- Calculate product-specific cost, not total procurement cost
- Use correct field references

---

## Testing Checklist

- [ ] Sales records display for correct product after date range applied
- [ ] Procurement records show only procurements containing this product
- [ ] Stats accurately reflect this product's sales/procurements
- [ ] Date range picker actually filters results
- [ ] Quantity extracted correctly from items array
- [ ] Cost for procurement shows only this product's portion
- [ ] Works with both `createdAt` and `timestamp` fields (for legacy data)
- [ ] No "No records" when data exists for product

