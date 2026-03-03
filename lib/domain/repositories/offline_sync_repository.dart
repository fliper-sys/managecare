/// Abstract offline sync repository
abstract class OfflineSyncRepository {
  Future<void> savePendingSale(Map<String, dynamic> saleData);
  Future<void> savePendingInventory(Map<String, dynamic> inventoryData);
  Future<List<dynamic>> getPendingSales(String businessId);
  Future<List<dynamic>> getPendingInventory(String businessId);
  Future<void> clearPendingSale(String saleId);
  Future<void> clearPendingInventory(String inventoryId);
  Future<void> syncAllPending(String businessId);
}

