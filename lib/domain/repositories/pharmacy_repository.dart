abstract class PharmacyRepository {
  /// Fetches dashboard stats: prescriptions today and expiring soon count.
  Future<Map<String, dynamic>> getDashboardStats(String businessId);

  /// Fetches recent prescriptions.
  Future<List<Map<String, dynamic>>> getRecentPrescriptions(String businessId);

  /// Fetches expiry alert count for items expiring within 7 days.
  Future<int> getExpiringItemCount(String businessId);
}

