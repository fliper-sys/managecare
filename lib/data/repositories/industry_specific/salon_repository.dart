abstract class SalonRepository {
  Future<List<Map<String, dynamic>>> fetchAppointments(String businessId);
  Future<void> bookAppointment(Map<String, dynamic> appointment);
  Future<List<Map<String, dynamic>>> fetchStylists(String businessId);
}

