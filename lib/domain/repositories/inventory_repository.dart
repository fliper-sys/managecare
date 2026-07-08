/// Abstract inventory repository
abstract class InventoryRepository {
  Future<dynamic> addInventory(Map<String, dynamic> inventoryData);
  Future<void> updateInventory(
      String inventoryId, Map<String, dynamic> inventoryData);
  Future<void> deleteInventory(String inventoryId);
  Future<List<dynamic>> getInventory(String businessId,
      {Map<String, dynamic>? filters, String? storeId});
  Future<dynamic> getInventoryById(String inventoryId);
  Future<List<dynamic>> getLowStockItems(String businessId, {String? storeId});
  Future<List<dynamic>> getExpiredItems(String businessId, {String? storeId});
  Future<List<Map<String, dynamic>>> fetchInventory({String? businessId, String? storeId});
  Future<List<dynamic>> expiredItems(String businessId);
  Future<void> syncInventoryToFirestore(Map<String, dynamic> inventoryData);
  /// Stream inventory for real-time updates, optionally scoped to a store
  Stream<List<Map<String, dynamic>>> streamInventory(String businessId, {String? storeId});

  /// Add a history log entry for a specific inventory item
  Future<void> addHistoryEntry(String businessId, String inventoryId, Map<String, dynamic> entry);

  /// Record a bakery stock resupply issued to a baker for production.
  Future<void> recordBakeryResupply({
    required String businessId,
    required String inventoryId,
    required num quantity,
    String? bakerId,
    String? bakerName,
    String? notes,
    String? performedById,
    String? performedByName,
  });

  /// Stream inventory history for an item (ordered by createdAt desc)
  Stream<List<Map<String, dynamic>>> streamInventoryHistory(String businessId, String inventoryId);

  /// Migration helper: assign all existing business inventory items to a store
  Future<int> assignAllInventoryToStore(String businessId, String storeId);
}

