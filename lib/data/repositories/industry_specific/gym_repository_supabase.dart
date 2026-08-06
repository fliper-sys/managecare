import 'package:supabase_flutter/supabase_flutter.dart';
import 'gym_repository.dart';

/// Supabase/Postgres-backed GymRepository.
class GymRepositorySupabase implements GymRepository {
  final SupabaseClient _supabase;
  final String businessId;

  GymRepositorySupabase({
    SupabaseClient? supabase,
    required this.businessId,
  }) : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<void> saveMember(Map<String, dynamic> memberData) async {
    final data = Map<String, dynamic>.from(memberData)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = memberData['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('gym_members').update(data).eq('id', id);
    } else {
      await _supabase.from('gym_members').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMembers() async {
    final result = await _supabase
        .from('gym_members')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> updateMember(String id, Map<String, dynamic> data) async {
    final update = Map<String, dynamic>.from(data)..remove('id');
    await _supabase.from('gym_members').update(update).eq('id', id);
  }

  @override
  Future<void> deleteMember(String id) async {
    await _supabase.from('gym_members').delete().eq('id', id);
  }

  @override
  Future<void> saveTrainer(Map<String, dynamic> trainerData) async {
    final data = Map<String, dynamic>.from(trainerData)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = trainerData['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('gym_trainers').update(data).eq('id', id);
    } else {
      await _supabase.from('gym_trainers').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTrainers() async {
    final result = await _supabase
        .from('gym_trainers')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> updateTrainer(String id, Map<String, dynamic> data) async {
    final update = Map<String, dynamic>.from(data)..remove('id');
    await _supabase.from('gym_trainers').update(update).eq('id', id);
  }

  @override
  Future<void> deleteTrainer(String id) async {
    await _supabase.from('gym_trainers').delete().eq('id', id);
  }

  @override
  Future<void> saveClass(Map<String, dynamic> classData) async {
    final data = Map<String, dynamic>.from(classData)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = classData['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('gym_classes').update(data).eq('id', id);
    } else {
      await _supabase.from('gym_classes').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClasses() async {
    final result = await _supabase
        .from('gym_classes')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> saveBooking(Map<String, dynamic> booking) async {
    final data = Map<String, dynamic>.from(booking)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = booking['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('gym_bookings').update(data).eq('id', id);
    } else {
      await _supabase.from('gym_bookings').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookings() async {
    final result = await _supabase
        .from('gym_bookings')
        .select('*, members:gym_members(name, phone)')
        .eq('business_id', businessId)
        .order('booking_date', ascending: false);
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> savePayment(Map<String, dynamic> payment) async {
    final data = Map<String, dynamic>.from(payment)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = payment['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('gym_payments').update(data).eq('id', id);
    } else {
      await _supabase.from('gym_payments').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPayments() async {
    final result = await _supabase
        .from('gym_payments')
        .select('*, members:gym_members(name)')
        .eq('business_id', businessId)
        .order('payment_date', ascending: false);
    return result.map((m) => _mapRow(m)).toList();
  }

  // Membership plans
  @override
  Future<void> savePlan(Map<String, dynamic> plan) async {
    final data = Map<String, dynamic>.from(plan)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = plan['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('gym_plans').update(data).eq('id', id);
    } else {
      await _supabase.from('gym_plans').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlans() async {
    final result = await _supabase
        .from('gym_plans')
        .select('*')
        .eq('business_id', businessId)
        .order('price');
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> updatePlan(String id, Map<String, dynamic> data) async {
    final update = Map<String, dynamic>.from(data)..remove('id');
    await _supabase.from('gym_plans').update(update).eq('id', id);
  }

  @override
  Future<void> deletePlan(String id) async {
    await _supabase.from('gym_plans').delete().eq('id', id);
  }

  // Equipment
  @override
  Future<void> saveEquipment(Map<String, dynamic> equipment) async {
    final data = Map<String, dynamic>.from(equipment)
      ..remove('id')
      ..['business_id'] = businessId;
    final id = equipment['id'] as String?;
    if (id != null && id.isNotEmpty) {
      await _supabase.from('gym_equipment').update(data).eq('id', id);
    } else {
      await _supabase.from('gym_equipment').insert(data);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEquipment() async {
    final result = await _supabase
        .from('gym_equipment')
        .select('*')
        .eq('business_id', businessId)
        .order('name');
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> updateEquipment(String id, Map<String, dynamic> data) async {
    final update = Map<String, dynamic>.from(data)..remove('id');
    await _supabase.from('gym_equipment').update(update).eq('id', id);
  }

  @override
  Future<void> deleteEquipment(String id) async {
    await _supabase.from('gym_equipment').delete().eq('id', id);
  }

  // Attendance
  @override
  Future<void> saveAttendanceRecord(Map<String, dynamic> record) async {
    final data = Map<String, dynamic>.from(record)
      ..remove('id')
      ..['business_id'] = businessId;
    await _supabase.from('gym_attendance').insert(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAttendanceRecords() async {
    final result = await _supabase
        .from('gym_attendance')
        .select('*, members:gym_members(name)')
        .eq('business_id', businessId)
        .order('check_in_time', ascending: false)
        .limit(100);
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> updateAttendanceRecord(String id, Map<String, dynamic> data) async {
    final update = Map<String, dynamic>.from(data)..remove('id');
    await _supabase.from('gym_attendance').update(update).eq('id', id);
  }

  @override
  Future<void> deleteAttendanceRecord(String id) async {
    await _supabase.from('gym_attendance').delete().eq('id', id);
  }

  // Measurements
  @override
  Future<void> saveMeasurement(Map<String, dynamic> measurement) async {
    final data = Map<String, dynamic>.from(measurement)
      ..remove('id')
      ..['business_id'] = businessId;
    await _supabase.from('gym_measurements').insert(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMeasurements() async {
    final result = await _supabase
        .from('gym_measurements')
        .select('*, members:gym_members(name)')
        .eq('business_id', businessId)
        .order('date', ascending: false)
        .limit(100);
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> updateMeasurement(String id, Map<String, dynamic> data) async {
    final update = Map<String, dynamic>.from(data)..remove('id');
    await _supabase.from('gym_measurements').update(update).eq('id', id);
  }

  @override
  Future<void> deleteMeasurement(String id) async {
    await _supabase.from('gym_measurements').delete().eq('id', id);
  }

  // Goals
  @override
  Future<void> saveGoal(Map<String, dynamic> goal) async {
    final data = Map<String, dynamic>.from(goal)
      ..remove('id')
      ..['business_id'] = businessId;
    await _supabase.from('gym_goals').insert(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGoals() async {
    final result = await _supabase
        .from('gym_goals')
        .select('*, members:gym_members(name)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .limit(100);
    return result.map((m) => _mapRow(m)).toList();
  }

  @override
  Future<void> updateGoal(String id, Map<String, dynamic> data) async {
    final update = Map<String, dynamic>.from(data)..remove('id');
    await _supabase.from('gym_goals').update(update).eq('id', id);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _supabase.from('gym_goals').delete().eq('id', id);
  }

  Map<String, dynamic> _mapRow(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    // Map snake_case from DB to camelCase for app
    return map;
  }
}

