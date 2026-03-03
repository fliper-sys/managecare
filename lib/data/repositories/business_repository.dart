abstract class BusinessRepository {
  Future<Map<String, dynamic>?> getBusinessDetails(String businessId);
  Future<List<Map<String, dynamic>>> listBusinesses();
  Future<void> updateBusiness(String businessId, Map<String, dynamic> data);
  Future<void> createBusiness(Map<String, dynamic> business);
  Future<List<Map<String, dynamic>>> getUserBusinesses(String userId);
}

