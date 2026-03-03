import '../usecase.dart';

/// Manages inventory stock levels, reorder points, and tracking
class ManageInventoryUseCase extends UseCase<void, ManageInventoryParams> {
  @override
  Future<void> call(ManageInventoryParams params) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class ManageInventoryParams {
  final String businessId;
  final String itemId;
  final int quantityChange; // positive for add, negative for remove
  final String reason; // purchase, sale, adjustment, damage, expiry
  final String? notes;

  ManageInventoryParams({
    required this.businessId,
    required this.itemId,
    required this.quantityChange,
    required this.reason,
    this.notes,
  });
}

/// Low stock alert use case
class CheckLowStockUseCase extends UseCase<List<LowStockAlert>, String> {
  @override
  Future<List<LowStockAlert>> call(String businessId) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class LowStockAlert {
  final String itemId;
  final String itemName;
  final int currentStock;
  final int reorderPoint;
  final double reorderQuantity;
  final DateTime alertDate;

  LowStockAlert({
    required this.itemId,
    required this.itemName,
    required this.currentStock,
    required this.reorderPoint,
    required this.reorderQuantity,
    required this.alertDate,
  });
}

/// Expiry tracking use case
class TrackExpiryUseCase extends UseCase<List<ExpiryAlert>, String> {
  @override
  Future<List<ExpiryAlert>> call(String businessId) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class ExpiryAlert {
  final String itemId;
  final String itemName;
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final int stock;
  final String severity; // critical, warning, info

  ExpiryAlert({
    required this.itemId,
    required this.itemName,
    required this.expiryDate,
    required this.daysUntilExpiry,
    required this.stock,
    required this.severity,
  });
}

/// Inventory valuation use case
class CalculateInventoryValueUseCase
    extends UseCase<InventoryValuation, String> {
  @override
  Future<InventoryValuation> call(String businessId) async {
    // Implementation handled by repository
    throw UnimplementedError();
  }
}

class InventoryValuation {
  final double totalValue;
  final int totalItems;
  final double avgItemValue;
  final Map<String, double> categoryValues;
  final DateTime calculatedAt;

  InventoryValuation({
    required this.totalValue,
    required this.totalItems,
    required this.avgItemValue,
    required this.categoryValues,
    required this.calculatedAt,
  });
}

