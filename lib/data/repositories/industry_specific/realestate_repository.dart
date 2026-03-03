abstract class RealEstateRepository {
  Future<List<Map<String, dynamic>>> fetchProperties(String businessId);
  Future<Map<String, dynamic>> addProperty(Map<String, dynamic> property);
  Future<List<Map<String, dynamic>>> fetchTenants(String businessId);
}

