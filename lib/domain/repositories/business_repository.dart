/// Abstract business repository
abstract class BusinessRepository {
  Future<dynamic> getBusiness(String businessId);
  Future<void> createBusiness(Map<String, dynamic> businessData);
  Future<void> updateBusiness(
      String businessId, Map<String, dynamic> businessData);
  Future<void> deleteBusiness(String businessId);
  Future<List<dynamic>> getAllBusinesses(String userId);
}

