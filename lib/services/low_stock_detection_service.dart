import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/repositories/inventory_repository_supabase.dart';

/// Unified low stock detection service for all business types
/// Provides consistent detection logic across all screens and dashboards
class LowStockDetectionService {
  final InventoryRepositorySupabase _inventoryRepo;

  LowStockDetectionService({InventoryRepositorySupabase? inventoryRepo})
      : _inventoryRepo = inventoryRepo ?? InventoryRepositorySupabase();

  /// Helper method to get quantity from product document
  /// Supports both 'quantity' field (Salon, Agriculture) and 'stock' field (Retail)
  int _getProductQuantity(Map<String, dynamic> data) {
    // Try 'quantity' field first (used by Salon, Agriculture, etc.)
    final qty = data['quantity'] as num?;
    if (qty != null) return qty.toInt();

    // Try 'stock' field (used by Retail)
    final stock = data['stock'] as num?;
    if (stock != null) return stock.toInt();

    // Default to 0 if neither field exists
    return 0;
  }

  /// Fetch every inventory row for a business from the Postgres-backed API.
  /// The `businesses/inventory/products` split that used to exist across
  /// Firestore subcollections doesn't exist here - the backend already
  /// unifies everything into a single `inventory` table per business.
  Future<List<Map<String, dynamic>>> _fetchAllProducts(
      String businessId) async {
    final rows = await _inventoryRepo.getInventory(businessId);
    return rows
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  /// Detect low stock products with configurable threshold
  ///
  /// Usage:
  /// ```dart
  /// final lowStockItems = await service.detectLowStockProducts(
  ///   businessId: 'biz123',
  ///   threshold: 10,
  /// );
  /// ```
  Future<List<LowStockProduct>> detectLowStockProducts({
    required String businessId,
    int threshold = 10,
    bool sortByQuantity = true,
  }) async {
    try {
      debugPrint('[LowStockService] Detecting low stock items...');
      debugPrint('[LowStockService] Business: $businessId, Threshold: $threshold');

      final rows = await _fetchAllProducts(businessId);

      debugPrint('[LowStockService] Total products fetched: ${rows.length}');

      final lowStockItems = rows
          .map((data) => _productFromRow(data, defaultThreshold: threshold))
          .where((product) => product.quantity <= threshold)
          .toList();

      // Sort by quantity ascending (lowest stock first) if requested
      if (sortByQuantity) {
        lowStockItems.sort((a, b) => a.quantity.compareTo(b.quantity));
      }

      debugPrint('[LowStockService] Low stock items detected: ${lowStockItems.length}');
      return lowStockItems;
    } catch (e) {
      debugPrint('[LowStockService] Error detecting low stock: $e');
      rethrow;
    }
  }

  /// Get count of low stock items
  Future<int> getLowStockCount({
    required String businessId,
    int threshold = 10,
  }) async {
    try {
      final items = await detectLowStockProducts(
        businessId: businessId,
        threshold: threshold,
      );
      return items.length;
    } catch (e) {
      debugPrint('[LowStockService] Error getting low stock count: $e');
      return 0;
    }
  }

  /// Get critical items (quantity == 0)
  Future<List<LowStockProduct>> getCriticalItems({
    required String businessId,
  }) async {
    try {
      final rows = await _fetchAllProducts(businessId);

      final criticalItems = rows
          .map((data) => _productFromRow(data, defaultThreshold: 0))
          .where((product) => product.quantity == 0)
          .toList();

      return criticalItems;
    } catch (e) {
      debugPrint('[LowStockService] Error getting critical items: $e');
      return [];
    }
  }

  LowStockProduct _productFromRow(
    Map<String, dynamic> data, {
    required int defaultThreshold,
  }) {
    final qty = _getProductQuantity(data);
    return LowStockProduct(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? 'Unknown').toString(),
      quantity: qty,
      unit: (data['unit'] ?? 'units').toString(),
      reorderLevel: (data['reorderLevel'] as num?)?.toInt() ??
          (data['min_stock_level'] as num?)?.toInt() ??
          defaultThreshold,
      costPrice: (data['costPrice'] as num?)?.toDouble() ??
          (data['cost_price'] as num?)?.toDouble() ??
          0.0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ??
          (data['unit_price'] as num?)?.toDouble() ??
          0.0,
      category: (data['category'] ?? 'General').toString(),
      supplier: (data['supplier'] ?? 'Not specified').toString(),
      lastRestocked:
          _parseExpiryDate(data['lastRestocked'] ?? data['updated_at']),
      minStockThreshold: defaultThreshold,
    );
  }

  /// Get stock status with severity level
  StockStatus getStockStatus({
    required int quantity,
    required int threshold,
  }) {
    if (quantity == 0) {
      return StockStatus.outOfStock;
    } else if (quantity <= threshold * 0.33) {
      return StockStatus.critical;
    } else if (quantity <= threshold) {
      return StockStatus.low;
    } else if (quantity > threshold * 3) {
      return StockStatus.overstock;
    } else {
      return StockStatus.normal;
    }
  }

  DateTime? _parseExpiryDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Detect expiring or expired products within the given window
  Future<List<ExpiringProduct>> detectExpiringProducts({
    required String businessId,
    int daysThreshold = 7,
    bool includeExpired = true,
    bool sortByExpiryDate = true,
  }) async {
    try {
      final now = DateTime.now();
      final rows = await _fetchAllProducts(businessId);

      final expiringItems = rows
          .map((data) {
            final expiryDate =
                _parseExpiryDate(data['expiryDate'] ?? data['expiry_date']);
            final qty = _getProductQuantity(data);
            if (expiryDate == null || qty <= 0) return null;

            final daysUntilExpiry = expiryDate.difference(now).inDays;
            final shouldInclude = (includeExpired && expiryDate.isBefore(now)) ||
                daysUntilExpiry <= daysThreshold;
            if (!shouldInclude) return null;

            return ExpiringProduct(
              id: (data['id'] ?? '').toString(),
              name: (data['name'] ?? 'Unknown').toString(),
              quantity: qty,
              unit: (data['unit'] ?? 'units').toString(),
              expiryDate: expiryDate,
              daysUntilExpiry: daysUntilExpiry,
              category: (data['category'] ?? 'General').toString(),
              supplier: (data['supplier'] ?? 'Not specified').toString(),
            );
          })
          .whereType<ExpiringProduct>()
          .toList();

      if (sortByExpiryDate) {
        expiringItems.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      }

      return expiringItems;
    } catch (e) {
      debugPrint('[LowStockService] Error detecting expiring products: $e');
      rethrow;
    }
  }

  /// Get count of expiring items within a given threshold
  Future<int> getExpiringCount({
    required String businessId,
    int daysThreshold = 7,
    bool includeExpired = true,
  }) async {
    try {
      final items = await detectExpiringProducts(
        businessId: businessId,
        daysThreshold: daysThreshold,
        includeExpired: includeExpired,
      );
      return items.length;
    } catch (e) {
      debugPrint('[LowStockService] Error getting expiring count: $e');
      return 0;
    }
  }

  /// Get stock status color
  String getStatusColor(StockStatus status) {
    switch (status) {
      case StockStatus.outOfStock:
        return '#FF0000'; // Red
      case StockStatus.critical:
        return '#FF5722'; // Deep Orange
      case StockStatus.low:
        return '#FFA500'; // Orange
      case StockStatus.normal:
        return '#4CAF50'; // Green
      case StockStatus.overstock:
        return '#2196F3'; // Blue
    }
  }

  /// Get severity label
  String getSeverityLabel(StockStatus status) {
    switch (status) {
      case StockStatus.outOfStock:
        return '❌ Out of Stock';
      case StockStatus.critical:
        return '🔴 Critical';
      case StockStatus.low:
        return '🟠 Low';
      case StockStatus.normal:
        return '🟢 Normal';
      case StockStatus.overstock:
        return '🔵 Overstock';
    }
  }

  /// Stream low stock products for near-real-time updates. The custom
  /// backend is a plain REST API (no Firestore-style realtime protocol), so
  /// this polls on an interval instead of subscribing - same approach as
  /// InventoryRepositorySupabase.streamInventory.
  static const _pollInterval = Duration(seconds: 15);

  Stream<List<LowStockProduct>> streamLowStockProducts({
    required String businessId,
    int threshold = 10,
  }) async* {
    while (true) {
      try {
        yield await detectLowStockProducts(
          businessId: businessId,
          threshold: threshold,
        );
      } catch (e) {
        debugPrint('[LowStockService] Error streaming low stock products: $e');
      }
      await Future.delayed(_pollInterval);
    }
  }

  /// Batch check multiple products for low stock status
  Future<Map<String, bool>> checkProductsLowStock({
    required String businessId,
    required List<String> productIds,
    int threshold = 10,
  }) async {
    try {
      final result = <String, bool>{};
      final rows = await _fetchAllProducts(businessId);

      final productMap = {
        for (final row in rows) (row['id'] ?? '').toString(): row,
      };

      for (final productId in productIds) {
        if (productMap.containsKey(productId)) {
          final data = productMap[productId]!;
          final qty = _getProductQuantity(data);
          result[productId] = qty <= threshold;
        } else {
          result[productId] = false;
        }
      }

      return result;
    } catch (e) {
      debugPrint('[LowStockService] Error checking products: $e');
      rethrow;
    }
  }

  /// Get low stock summary statistics
  Future<LowStockSummary> getLowStockSummary({
    required String businessId,
    int threshold = 10,
  }) async {
    try {
      final rows = await _fetchAllProducts(businessId);

      int totalProducts = rows.length;
      int lowStockCount = 0;
      int criticalCount = 0;
      double potentialLoss = 0;

      for (final data in rows) {
        final qty = _getProductQuantity(data);
        final costPrice = (data['costPrice'] as num?)?.toDouble() ??
            (data['cost_price'] as num?)?.toDouble() ??
            0.0;

        if (qty == 0) {
          criticalCount++;
          potentialLoss += costPrice;
        } else if (qty <= threshold) {
          lowStockCount++;
        }
      }

      return LowStockSummary(
        totalProducts: totalProducts,
        lowStockCount: lowStockCount,
        criticalCount: criticalCount,
        potentialLoss: potentialLoss,
        percentageLow: totalProducts > 0 ? (lowStockCount / totalProducts) * 100 : 0,
      );
    } catch (e) {
      debugPrint('[LowStockService] Error getting summary: $e');
      rethrow;
    }
  }
}

/// Model representing a low stock product
class LowStockProduct {
  final String id;
  final String name;
  final int quantity;
  final String unit;
  final int reorderLevel;
  final double costPrice;
  final double sellingPrice;
  final String category;
  final String supplier;
  final DateTime? lastRestocked;
  final int minStockThreshold;

  LowStockProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.reorderLevel,
    required this.costPrice,
    required this.sellingPrice,
    required this.category,
    required this.supplier,
    required this.lastRestocked,
    required this.minStockThreshold,
  });

  /// Get stock status
  StockStatus get status {
    if (quantity == 0) {
      return StockStatus.outOfStock;
    } else if (quantity <= minStockThreshold * 0.33) {
      return StockStatus.critical;
    } else if (quantity <= minStockThreshold) {
      return StockStatus.low;
    } else {
      return StockStatus.normal;
    }
  }

  /// Get formatted last restocked date
  String get formattedLastRestocked {
    if (lastRestocked == null) return 'Never';
    final date = lastRestocked!;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }

  /// Calculate reorder quantity
  int get recommendedReorderQuantity => (reorderLevel * 2).toInt();

  /// Get potential loss value (cost of out-of-stock items)
  double get potentialLoss => costPrice * (reorderLevel - quantity).clamp(0, reorderLevel);
}

/// Model representing an expiring or expired product
class ExpiringProduct {
  final String id;
  final String name;
  final int quantity;
  final String unit;
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final String category;
  final String supplier;

  ExpiringProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.category,
    required this.supplier,
  });

  String get formattedExpiryDate => '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';

  String get expiryStatus {
    if (daysUntilExpiry < 0) {
      return 'Expired ${-daysUntilExpiry} day${(-daysUntilExpiry) == 1 ? '' : 's'} ago';
    }
    return 'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
  }
}

/// Low stock summary statistics
class LowStockSummary {
  final int totalProducts;
  final int lowStockCount;
  final int criticalCount;
  final double potentialLoss;
  final double percentageLow;

  LowStockSummary({
    required this.totalProducts,
    required this.lowStockCount,
    required this.criticalCount,
    required this.potentialLoss,
    required this.percentageLow,
  });

  /// Get health status
  String get healthStatus {
    if (percentageLow > 50) {
      return 'Critical';
    } else if (percentageLow > 20) {
      return 'Warning';
    } else if (percentageLow > 0) {
      return 'Caution';
    } else {
      return 'Healthy';
    }
  }

  /// Get health color
  String get healthColor {
    if (percentageLow > 50) {
      return '#FF0000'; // Red
    } else if (percentageLow > 20) {
      return '#FFA500'; // Orange
    } else if (percentageLow > 0) {
      return '#FFEB3B'; // Yellow
    } else {
      return '#4CAF50'; // Green
    }
  }
}

/// Stock status enum
enum StockStatus {
  outOfStock,
  critical,
  low,
  normal,
  overstock,
}
