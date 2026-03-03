abstract class AutoRepository {
  /// Fetches stats for dashboard: active jobs, pending, and completed counts.
  Future<Map<String, dynamic>> getDashboardStats(String businessId);

  /// Fetches all service orders for the business.
  Future<List<Map<String, dynamic>>> getServiceOrders(String businessId);

  /// Fetches all job cards for the business.
  Future<List<Map<String, dynamic>>> getJobCards(String businessId);

  /// Fetches all vehicles for the business.
  Future<List<Map<String, dynamic>>> getVehicles(String businessId);

  /// Fetches all invoices for the business.
  Future<List<Map<String, dynamic>>> getInvoices(String businessId);

  /// Fetches all bookings for the business.
  Future<List<Map<String, dynamic>>> getBookings(String businessId);

  /// Fetches parts/inventory for the business.
  Future<List<Map<String, dynamic>>> getParts(String businessId);

  /// Fetches service definitions (labor items) for the business.
  Future<List<Map<String, dynamic>>> getServices(String businessId);
}

