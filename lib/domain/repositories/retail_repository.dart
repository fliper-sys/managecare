abstract class RetailRepository {
  /// Fetches wholesale orders for the business.
  Future<List<Map<String, dynamic>>> getWholesaleOrders(String businessId);

  /// Fetches inventory for the business.
  Future<List<Map<String, dynamic>>> getInventory(String businessId);

  /// Fetches sales for the business.
  Future<List<Map<String, dynamic>>> getSales(String businessId);
}

