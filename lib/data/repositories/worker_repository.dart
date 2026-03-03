abstract class WorkerRepository {
  Future<List<Map<String, dynamic>>> fetchWorkers(String businessId);
  Future<void> addWorker(Map<String, dynamic> worker);
  Future<void> updateWorker(String id, Map<String, dynamic> updates);
  Future<void> removeWorker(String id);
}

