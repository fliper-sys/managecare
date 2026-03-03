abstract class AgriRepository {
  Future<List<Map<String, dynamic>>> fetchFarms(String businessId);
  Future<void> addCrop(Map<String, dynamic> crop);
  Future<List<Map<String, dynamic>>> fetchInputs(String businessId);

  // Farm persistence
  Future<void> saveFarm(String businessId, Map<String, dynamic> farm) async {}
  Future<void> deleteFarm(String businessId, String farmId) async {}

  /// Persist a generated hint for a farm (optional implementation).
  Future<void> saveHint(
      String businessId, String farmId, Map<String, dynamic> hint) async {}
  Future<List<Map<String, dynamic>>> fetchHints(String businessId,
          {String? farmId}) async =>
      [];

  // Livestock persistence
  Future<void> saveLivestockGroup(
      String businessId, Map<String, dynamic> group) async {}
  Future<List<Map<String, dynamic>>> fetchLivestockGroups(
          String businessId) async =>
      [];
  Future<void> deleteLivestockGroup(String businessId, String groupId) async {}
}

