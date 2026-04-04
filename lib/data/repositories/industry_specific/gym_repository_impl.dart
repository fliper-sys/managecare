import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'gym_repository.dart';

class GymRepositoryImpl implements GymRepository {
  final String businessId;
  final fs.FirebaseFirestore _db = fs.FirebaseFirestore.instance;

  GymRepositoryImpl({required this.businessId});

  @override
  Future<void> saveMember(Map<String, dynamic> member) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_members')
        .add(member);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMembers() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_members')
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> saveClass(Map<String, dynamic> classData) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_classes')
        .add(classData);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClasses() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_classes')
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> saveBooking(Map<String, dynamic> booking) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_bookings')
        .add(booking);
  }

  @override
  Future<void> saveTrainer(Map<String, dynamic> trainer) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_trainers')
        .add(trainer);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTrainers() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_trainers')
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookings() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_bookings')
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  // --- Plans ---
  @override
  Future<void> savePlan(Map<String, dynamic> plan) async {
    final collection = _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_plans');
    final id = (plan['id'] as String?) ?? '';
    if (id.isNotEmpty) {
      await collection.doc(id).set(plan);
    } else {
      await collection.add(plan);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlans() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_plans')
        .orderBy('price', descending: false)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> updatePlan(String id, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_plans')
        .doc(id)
        .set(data, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deletePlan(String id) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_plans')
        .doc(id)
        .delete();
  }

  @override
  Future<void> updateMember(String id, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_members')
        .doc(id)
        .set(data, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteMember(String id) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_members')
        .doc(id)
        .delete();
  }

  @override
  Future<void> updateTrainer(String id, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_trainers')
        .doc(id)
        .set(data, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteTrainer(String id) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_trainers')
        .doc(id)
        .delete();
  }

  @override
  Future<void> savePayment(Map<String, dynamic> payment) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_payments')
        .add(payment);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPayments() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_payments')
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  // Equipment management
  @override
  Future<void> saveEquipment(Map<String, dynamic> equipment) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_equipment')
        .add(equipment);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEquipment() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_equipment')
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> updateEquipment(String id, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_equipment')
        .doc(id)
        .set(data, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteEquipment(String id) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_equipment')
        .doc(id)
        .delete();
  }

  // Attendance tracking
  @override
  Future<void> saveAttendanceRecord(Map<String, dynamic> record) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_attendance')
        .add(record);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAttendanceRecords() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_attendance')
        .orderBy('checkInTime', descending: true)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> updateAttendanceRecord(String id, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_attendance')
        .doc(id)
        .set(data, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteAttendanceRecord(String id) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_attendance')
        .doc(id)
        .delete();
  }

  // Fitness measurements
  @override
  Future<void> saveMeasurement(Map<String, dynamic> measurement) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_measurements')
        .add(measurement);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMeasurements() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_measurements')
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> updateMeasurement(String id, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_measurements')
        .doc(id)
        .set(data, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteMeasurement(String id) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_measurements')
        .doc(id)
        .delete();
  }

  // Fitness goals
  @override
  Future<void> saveGoal(Map<String, dynamic> goal) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_goals')
        .add(goal);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGoals() async {
    final snap = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_goals')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  @override
  Future<void> updateGoal(String id, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_goals')
        .doc(id)
        .set(data, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('gym_goals')
        .doc(id)
        .delete();
  }
}

