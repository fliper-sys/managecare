abstract class InventoryRepository {
  Future<List<Map<String, dynamic>>> fetchInventory(String businessId);
  Future<void> addItem(Map<String, dynamic> item);
  Future<void> updateStock(String itemId, int newQuantity);
  Future<List<Map<String, dynamic>>> expiredItems(String businessId);
  Future<void> syncInventoryToFirestore(Map<String, dynamic> itemData);
}

