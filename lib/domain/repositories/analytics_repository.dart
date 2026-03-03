/// Abstract analytics repository
abstract class AnalyticsRepository {
  Future<dynamic> getSalesAnalytics(String businessId,
      {required DateTime startDate, required DateTime endDate});
  Future<dynamic> getInventoryAnalytics(String businessId);
  Future<dynamic> getCustomerAnalytics(String businessId);
  Future<dynamic> getRevenueReport(String businessId,
      {required DateTime startDate, required DateTime endDate});
}

