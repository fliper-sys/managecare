/// Typed interface for Gym repository operations.
abstract class GymRepository {
  Future<void> saveMember(Map<String, dynamic> memberData);
  Future<List<Map<String, dynamic>>> fetchMembers();

  Future<void> saveTrainer(Map<String, dynamic> trainerData);
  Future<List<Map<String, dynamic>>> fetchTrainers();

  Future<void> saveClass(Map<String, dynamic> classData);
  Future<List<Map<String, dynamic>>> fetchClasses();

  Future<void> saveBooking(Map<String, dynamic> booking);
  Future<List<Map<String, dynamic>>> fetchBookings();

  Future<void> updateMember(String id, Map<String, dynamic> data);
  Future<void> deleteMember(String id);

  Future<void> updateTrainer(String id, Map<String, dynamic> data);
  Future<void> deleteTrainer(String id);

  Future<void> savePayment(Map<String, dynamic> payment);
  Future<List<Map<String, dynamic>>> fetchPayments();

  // Membership plans support
  Future<void> savePlan(Map<String, dynamic> plan);
  Future<List<Map<String, dynamic>>> fetchPlans();
  Future<void> updatePlan(String id, Map<String, dynamic> data);
  Future<void> deletePlan(String id);

  // Equipment management
  Future<void> saveEquipment(Map<String, dynamic> equipment);
  Future<List<Map<String, dynamic>>> fetchEquipment();
  Future<void> updateEquipment(String id, Map<String, dynamic> data);
  Future<void> deleteEquipment(String id);

  // Attendance tracking
  Future<void> saveAttendanceRecord(Map<String, dynamic> record);
  Future<List<Map<String, dynamic>>> fetchAttendanceRecords();
  Future<void> updateAttendanceRecord(String id, Map<String, dynamic> data);
  Future<void> deleteAttendanceRecord(String id);

  // Fitness measurements
  Future<void> saveMeasurement(Map<String, dynamic> measurement);
  Future<List<Map<String, dynamic>>> fetchMeasurements();
  Future<void> updateMeasurement(String id, Map<String, dynamic> data);
  Future<void> deleteMeasurement(String id);

  // Fitness goals
  Future<void> saveGoal(Map<String, dynamic> goal);
  Future<List<Map<String, dynamic>>> fetchGoals();
  Future<void> updateGoal(String id, Map<String, dynamic> data);
  Future<void> deleteGoal(String id);
}

