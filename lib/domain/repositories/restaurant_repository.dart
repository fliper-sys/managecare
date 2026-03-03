abstract class RestaurantRepository {
  /// Fetches dashboard stats: active tables, kitchen queue, and revenue.
  Future<Map<String, dynamic>> getDashboardStats(String businessId);

  /// Fetches all tables for the business.
  Future<List<Map<String, dynamic>>> getTables(String businessId);

  /// Fetches all active orders (Preparing/Ready status).
  Future<List<Map<String, dynamic>>> getActiveOrders(String businessId);
}

