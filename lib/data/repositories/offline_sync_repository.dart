abstract class OfflineSyncRepository {
  Future<void> queueChange(Map<String, dynamic> change);
  Future<void> flushQueuedChanges();
  Future<List<Map<String, dynamic>>> getQueuedChanges();
}

