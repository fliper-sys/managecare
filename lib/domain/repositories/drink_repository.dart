abstract class DrinkRepository {
  /// Fetches brewing logs for the business.
  Future<List<Map<String, dynamic>>> getBrewingLogs(String businessId);

  /// Fetches distribution orders for the business.
  Future<List<Map<String, dynamic>>> getDistributionOrders(String businessId);

  /// Fetches inventory for the business.
  Future<List<Map<String, dynamic>>> getInventory(String businessId);
}

