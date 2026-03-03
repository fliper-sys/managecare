abstract class AnalyticsRepository {
  Future<void> logEvent(String name, Map<String, dynamic>? params);
  Future<Map<String, dynamic>> fetchAnalyticsOverview(String businessId);
}

