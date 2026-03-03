abstract class DrinkRepository {
  Future<List<Map<String, dynamic>>> fetchBeverages(String businessId);
  Future<void> addBottle(Map<String, dynamic> bottle);
  Future<List<Map<String, dynamic>>> fetchTabs(String businessId);
}

