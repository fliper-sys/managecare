abstract class PayrollRepository {
  Future<List<Map<String, dynamic>>> getPayrollRecords(
    String businessId,
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Map<String, dynamic>> getPayrollSummary(
    String businessId,
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<void> recordPayroll(
    String businessId,
    String workerId,
    Map<String, dynamic> payrollData,
  );

  Future<void> updatePayroll(
    String businessId,
    String payrollId,
    Map<String, dynamic> updates,
  );
}

