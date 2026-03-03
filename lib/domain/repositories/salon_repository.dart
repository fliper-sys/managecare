abstract class SalonRepository {
  /// Fetches dashboard stats: appointments, available slots, and revenue.
  Future<Map<String, dynamic>> getDashboardStats(String businessId);

  /// Fetches all appointments for today.
  Future<List<Map<String, dynamic>>> getTodayAppointments(String businessId);

  /// Fetches all stylists on duty.
  Future<List<Map<String, dynamic>>> getStylists(String businessId);
}

