abstract class AttendanceRepository {
  Future<List<Map<String, dynamic>>> getAttendanceRecords(
    String businessId,
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, dynamic>> getAttendanceStats(
    String businessId,
    String workerId,
  );

  Future<void> recordAttendance(
    String businessId,
    String workerId,
    Map<String, dynamic> record,
  );

  Future<void> updateAttendance(
    String businessId,
    String recordId,
    Map<String, dynamic> updates,
  );
}

