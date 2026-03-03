abstract class AutoRepository {
  Future<List<Map<String, dynamic>>> fetchVehicles(String businessId);
  Future<Map<String, dynamic>> createServiceOrder(Map<String, dynamic> order);
  Future<List<Map<String, dynamic>>> fetchParts(String businessId);
}

