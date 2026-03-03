/// Abstract worker/employee repository
abstract class WorkerRepository {
  Future<dynamic> addWorker(Map<String, dynamic> workerData);
  Future<void> updateWorker(String workerId, Map<String, dynamic> workerData);
  Future<void> deleteWorker(String workerId);
  Future<List<dynamic>> getWorkers(String businessId);
  Future<dynamic> getWorkerById(String workerId);
  Future<void> recordAttendance(
      String workerId, Map<String, dynamic> attendanceData);
  Future<List<dynamic>> getWorkerAttendance(String workerId);
}

