# Product Details Screen - Exact Code Fixes

## File: `lib/presentation/inventory/screens/product_details_screen.dart`

This document shows the exact code changes needed to fix the sales and procurement record fetching.

---

## FIX #1: Add Helper Methods at Class Level

**Location:** Add these methods to `_ProductDetailsScreenState` class

```dart
// Helper: Parse timestamp from various formats
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

// Helper: Extract product quantity from sale
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

// Helper: Extract product cost from procurement item
double _extractProductCostFromProcurement(Map<String, dynamic> procItem) {
  // Try different field names for cost
  final total = procItem['total'] ?? 
                procItem['cost'] ?? 
                ((procItem['quantity'] ?? 0) * (procItem['unitCost'] ?? 0)) ?? 
                0;
  
  if (total is num) return total.toDouble();
  return double.tryParse(total.toString()) ?? 0.0;
}
```

---

## FIX #2: Update `_buildSalesHistoryList()` Method

**OLD CODE:**
```dart
Widget _buildSalesHistoryList() {
  final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
  final businessId = businessProvider.currentBusiness?.id ?? '';
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '₦');
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Sales Records', style: AppTextStyles.heading5),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .where('items', arrayContains: widget.productId)  // ❌ BROKEN
            .orderBy('timestamp', descending: true)           // ❌ WRONG FIELD
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No sales records found'),
            );
          }
          
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final saleDoc = snapshot.data!.docs[index];
              final saleData = saleDoc.data() as Map<String, dynamic>;
              final timestamp = (saleData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final formattedDate = DateFormat('MMM dd, yyyy').format(timestamp);
              
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
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sale #${saleDoc.id.substring(0, 8).toUpperCase()}',
                              style: AppTextStyles.body2.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total: ${currencyFormat.format(saleData['total'] ?? 0)}',
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
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
  );
}
```

**NEW CODE:**
```dart
Widget _buildSalesHistoryList() {
  final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
  final businessId = businessProvider.currentBusiness?.id ?? '';
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '₦');
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Sales Records', style: AppTextStyles.heading5),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        // ✅ FIXED: Query by createdAt with date range
        stream: FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .orderBy('createdAt', descending: true)  // ✅ Use createdAt not timestamp
            .limit(100)  // Fetch more since we'll filter client-side
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No sales records found'),
            );
          }
          
          // ✅ FIXED: Filter for sales containing this product
          final salesWithProduct = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final items = (data['items'] as List?) ?? [];
            
            // Check if any item in this sale matches this product
            return items.any((item) => 
              item is Map && 
              (item['productId'] == widget.productId || 
               item['product_id'] == widget.productId)
            );
          }).toList();
          
          // ✅ FIXED: Apply date range filter
          final filtered = salesWithProduct.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = _parseTimestamp(data['createdAt'] ?? data['timestamp']);
            
            if (_dateRange == null) return true;
            
            return !timestamp.isBefore(_dateRange!.start) && 
                   !timestamp.isAfter(_dateRange!.end);
          }).toList();
          
          if (filtered.isEmpty) {
            return const Center(
              child: Text('No sales records found for this product'),
            );
          }
          
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final saleDoc = filtered[index];
              final saleData = saleDoc.data() as Map<String, dynamic>;
              
              // ✅ FIXED: Parse timestamp correctly
              final timestamp = _parseTimestamp(saleData['createdAt'] ?? saleData['timestamp']);
              final formattedDate = DateFormat('MMM dd, yyyy').format(timestamp);
              
              // ✅ FIXED: Extract total correctly - could be 'total', 'totalAmount', or 'finalAmount'
              final totalAmount = (saleData['finalAmount'] ?? 
                                  saleData['totalAmount'] ?? 
                                  saleData['total'] ?? 0) as num;
              
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
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sale #${saleDoc.id.substring(0, 8).toUpperCase()}',
                              style: AppTextStyles.body2.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total: ${currencyFormat.format(totalAmount)}',
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 4),
                            // ✅ NEW: Show quantity of this product sold
                            Text(
                              'Qty: ${_extractProductQuantityFromSale(saleData)} units',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.success),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
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
  );
}
```

---

## FIX #3: Update `_buildProcurementHistoryTab()` Method

**OLD CODE:**
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
                  .doc(Provider.of<BusinessProvider>(context, listen: false).currentBusiness?.id ?? '')
                  .collection('procurements')
                  .orderBy('timestamp', descending: true)  // ❌ WRONG FIELD
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No procurement records found'),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final procDoc = snapshot.data!.docs[index];
                    final procData = procDoc.data() as Map<String, dynamic>;
                    final timestamp = (procData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final formattedDate = DateFormat('MMM dd, yyyy').format(timestamp);
                    final status = procData['status'] ?? 'pending';
                    
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
                                    style: AppTextStyles.body2.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                        'Cost: ₦${(procData['totalCost'] ?? 0).toStringAsFixed(0)}',  // ❌ Shows entire procurement cost
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: status == 'received' ? AppColors.success.withOpacity(0.2) : AppColors.warning.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: AppTextStyles.caption.copyWith(
                                            color: status == 'received' ? AppColors.success : AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
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

**NEW CODE:**
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
              // ✅ FIXED: Query by createdAt not timestamp
              stream: FirebaseFirestore.instance
                  .collection('businesses')
                  .doc(businessId)
                  .collection('procurements')
                  .orderBy('createdAt', descending: true)  // ✅ Use createdAt
                  .limit(50)  // Fetch more since we'll filter client-side
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No procurement records found'),
                  );
                }
                
                // ✅ FIXED: Filter for procurements containing this product only
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
                  return const Center(
                    child: Text('No procurements found for this product'),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: procurementsForProduct.length,
                  itemBuilder: (context, index) {
                    final procDoc = procurementsForProduct[index];
                    final procData = procDoc.data() as Map<String, dynamic>;
                    
                    // ✅ FIXED: Parse timestamp correctly
                    final timestamp = _parseTimestamp(procData['createdAt'] ?? procData['timestamp']);
                    final formattedDate = DateFormat('MMM dd, yyyy').format(timestamp);
                    final status = procData['status'] ?? 'pending';
                    
                    // ✅ FIXED: Extract this product's details from the procurement
                    final items = (procData['items'] as List?) ?? [];
                    final productItem = items.firstWhere(
                      (item) => item is Map && 
                               (item['productId'] == widget.productId || 
                                item['product_id'] == widget.productId),
                      orElse: () => null,
                    );
                    
                    if (productItem == null) return const SizedBox.shrink();
                    
                    // ✅ FIXED: Calculate product-specific cost, not entire procurement cost
                    final productCost = _extractProductCostFromProcurement(productItem as Map<String, dynamic>);
                    final productQty = (productItem['quantity'] ?? 0) as num;
                    
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
                                    style: AppTextStyles.body2.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Invoice: ${procData['invoiceRef'] ?? procDoc.id.substring(0, 8)}',
                                    style: AppTextStyles.caption,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      // ✅ NEW: Show product quantity
                                      Text(
                                        'Qty: ${productQty.toInt()} units',
                                        style: AppTextStyles.caption,
                                      ),
                                      const SizedBox(width: 8),
                                      // ✅ FIXED: Show product-specific cost
                                      Text(
                                        'Cost: ₦${productCost.toStringAsFixed(0)}',
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
                                    formattedDate,
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

## FIX #4: Update `_calculateSalesStats()` Method

**OLD CODE:**
```dart
Future<Map<String, dynamic>> _calculateSalesStats(String businessId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .where('items', arrayContains: widget.productId)  // ❌ BROKEN
        .get();
    
    int totalUnits = 0;
    double revenue = 0.0;
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      revenue += (data['total'] as num?)?.toDouble() ?? 0.0;  // ❌ Entire sale, not product
      final items = data['items'] as List?;
      if (items != null) {
        for (var item in items) {
          if (item is Map && item['productId'] == widget.productId) {
            totalUnits += (item['quantity'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }
    
    final cost = (revenue > 0) ? revenue * 0.65 : 0.0;
    final margin = (revenue > 0) ? ((revenue - cost) / revenue) * 100 : 0.0;
    
    return {
      'totalUnits': totalUnits,
      'revenue': revenue,
      'margin': margin,
    };
  } catch (e) {
    debugPrint('Error calculating sales stats: $e');
    return {'totalUnits': 0, 'revenue': 0.0, 'margin': 0.0};
  }
}
```

**NEW CODE:**
```dart
Future<Map<String, dynamic>> _calculateSalesStats(String businessId) async {
  try {
    // ✅ FIXED: Query without the broken arrayContains
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    
    int totalUnits = 0;
    double productRevenue = 0.0;  // Revenue from THIS PRODUCT only
    double productCost = 0.0;     // Cost of THIS PRODUCT only
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final items = (data['items'] as List?) ?? [];
      
      // ✅ FIXED: Only process items that match this product
      for (var item in items) {
        if (item is Map) {
          final itemProductId = item['productId'] ?? item['product_id'];
          
          if (itemProductId == widget.productId) {
            // Extract quantity using helper
            final qty = item['quantity'] ?? item['qty'] ?? 0;
            totalUnits += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 0;
            
            // Extract product revenue (item total, not entire sale)
            final itemTotal = item['total'] ?? 
                             (item['quantity'] * item['unitPrice']) ?? 
                             0;
            productRevenue += (itemTotal is num) ? itemTotal.toDouble() : 
                             double.tryParse(itemTotal.toString()) ?? 0.0;
            
            // Extract product cost
            final itemCost = item['cost'] ?? 
                            (item['quantity'] * item['unitCost']) ?? 
                            0;
            productCost += (itemCost is num) ? itemCost.toDouble() : 
                          double.tryParse(itemCost.toString()) ?? 0.0;
          }
        }
      }
    }
    
    // ✅ FIXED: Calculate margin based on product-specific revenue and cost
    final margin = (productRevenue > 0) 
        ? (((productRevenue - productCost) / productRevenue) * 100)
        : 0.0;
    
    return {
      'totalUnits': totalUnits,
      'revenue': productRevenue,
      'margin': margin,
    };
  } catch (e) {
    debugPrint('Error calculating sales stats: $e');
    return {'totalUnits': 0, 'revenue': 0.0, 'margin': 0.0};
  }
}
```

---

## FIX #5: Update `_calculateProcurementStats()` Method

**OLD CODE:**
```dart
Future<Map<String, dynamic>> _calculateProcurementStats(String businessId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('procurements')
        .get();
    
    int totalUnits = 0;
    double totalCost = 0.0;  // ❌ Calculates total of ALL procurements
    int pending = 0;
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] == 'pending') pending++;
      
      totalCost += (data['totalCost'] as num?)?.toDouble() ?? 0.0;  // ❌ WRONG
      final items = data['items'] as List?;
      if (items != null) {
        for (var item in items) {
          if (item is Map && item['productId'] == widget.productId) {
            totalUnits += (item['quantity'] as num?)?.toInt() ?? 0;
          }
        }
      }
    }
    
    return {
      'totalUnits': totalUnits,
      'totalCost': totalCost,  // Wrong value!
      'pending': pending,
    };
  } catch (e) {
    debugPrint('Error calculating procurement stats: $e');
    return {'totalUnits': 0, 'totalCost': 0.0, 'pending': 0};
  }
}
```

**NEW CODE:**
```dart
Future<Map<String, dynamic>> _calculateProcurementStats(String businessId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('procurements')
        .get();
    
    int totalUnits = 0;
    double productOnlyCost = 0.0;  // ✅ FIXED: Product-specific cost
    int pending = 0;
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      final items = (data['items'] as List?) ?? [];
      
      // ✅ FIXED: Only process items for this product
      for (var item in items) {
        if (item is Map) {
          final itemProductId = item['productId'] ?? item['product_id'];
          
          if (itemProductId == widget.productId) {
            // Extract quantity
            final qty = item['quantity'] ?? item['qty'] ?? 0;
            totalUnits += (qty is num) ? qty.toInt() : int.tryParse(qty.toString()) ?? 0;
            
            // ✅ FIXED: Extract THIS ITEM's cost, not entire procurement cost
            final itemCost = item['total'] ?? 
                            (item['quantity'] * item['unitCost']) ?? 
                            0;
            productOnlyCost += (itemCost is num) ? itemCost.toDouble() : 
                              double.tryParse(itemCost.toString()) ?? 0.0;
            
            // Count pending status for this product's orders
            if (data['status'] == 'pending') pending++;
          }
        }
      }
    }
    
    return {
      'totalUnits': totalUnits,
      'totalCost': productOnlyCost,  // ✅ FIXED: Now product-specific
      'pending': pending,
    };
  } catch (e) {
    debugPrint('Error calculating procurement stats: $e');
    return {'totalUnits': 0, 'totalCost': 0.0, 'pending': 0};
  }
}
```

---

## Summary of Changes

| Method | Issue | Fix |
|--------|-------|-----|
| `_buildSalesHistoryList()` | arrayContains broken, no date filter | Filter locally for product, apply date range |
| `_buildProcurementHistoryTab()` | No product filter, shows all procurements | Filter for this product only, show product cost |
| `_calculateSalesStats()` | Never executes due to broken query | Fetch all, filter client-side, calculate product revenue |
| `_calculateProcurementStats()` | Uses entire procurement cost | Calculate product-only cost portion |
| Helper Methods | Missing | Add `_parseTimestamp()`, `_extractProductQuantityFromSale()`, `_extractProductCostFromProcurement()` |

---

## Implementation Order

1. Add helper methods first ✅
2. Fix timestamp field (change `timestamp` → `createdAt`) ✅
3. Fix `_buildSalesHistoryList()` ✅
4. Fix `_buildProcurementHistoryTab()` ✅
5. Fix `_calculateSalesStats()` ✅
6. Fix `_calculateProcurementStats()` ✅
7. Test thoroughly

