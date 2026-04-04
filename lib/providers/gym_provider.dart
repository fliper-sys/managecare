import 'package:flutter/foundation.dart';
import '../data/models/gym_model.dart';
import '../data/models/gym_member_model.dart';
import '../data/models/gym_trainer_model.dart';
import '../data/repositories/industry_specific/gym_repository.dart';
import '../core/utils/datetime_utils.dart';
import '../services/notification_service.dart';
import '../services/notification_interface.dart';

// Member and Trainer are defined in separate model files for reuse.

class MembershipPlan {
  final String id;
  final String name;
  final double pricePerMonth;
  final int durationMonths;
  final List<String> features;
  final bool isActive;

  MembershipPlan({
    required this.id,
    required this.name,
    required this.pricePerMonth,
    this.durationMonths = 1,
    List<String>? features,
    this.isActive = true,
  }) : features = features ?? [];

  MembershipPlan copyWith({
    String? id,
    String? name,
    double? pricePerMonth,
    int? durationMonths,
    List<String>? features,
    bool? isActive,
  }) {
    return MembershipPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      pricePerMonth: pricePerMonth ?? this.pricePerMonth,
      durationMonths: durationMonths ?? this.durationMonths,
      features: features ?? List<String>.from(this.features),
      isActive: isActive ?? this.isActive,
    );
  }
} 

class ClassSession {
  final String id;
  final String title;
  final String trainerId;
  final DateTime start;
  final DateTime end;
  final int capacity;
  final List<String> bookedMemberIds;

  ClassSession(
      {required this.id,
      required this.title,
      required this.trainerId,
      required this.start,
      required this.end,
      this.capacity = 20,
      List<String>? bookedMemberIds})
      : bookedMemberIds = bookedMemberIds ?? [];
}

class Booking {
  final String id;
  final String memberId;
  final String classId;
  final DateTime bookedAt;

  Booking(
      {required this.id,
      required this.memberId,
      required this.classId,
      DateTime? bookedAt})
      : bookedAt = bookedAt ?? DateTime.now();
}

class Equipment {
  final String id;
  final String name;
  final String category;
  final String status; // 'available', 'in-use', 'maintenance', 'out-of-order'
  final DateTime? lastMaintenance;
  final DateTime? nextMaintenance;
  final String? notes;

  Equipment({
    required this.id,
    required this.name,
    required this.category,
    this.status = 'available',
    this.lastMaintenance,
    this.nextMaintenance,
    this.notes,
  });

  Equipment copyWith({
    String? id,
    String? name,
    String? category,
    String? status,
    DateTime? lastMaintenance,
    DateTime? nextMaintenance,
    String? notes,
  }) {
    return Equipment(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      status: status ?? this.status,
      lastMaintenance: lastMaintenance ?? this.lastMaintenance,
      nextMaintenance: nextMaintenance ?? this.nextMaintenance,
      notes: notes ?? this.notes,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String memberId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.memberId,
    required this.checkInTime,
    this.checkOutTime,
    this.notes,
  });

  AttendanceRecord copyWith({
    String? id,
    String? memberId,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? notes,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      notes: notes ?? this.notes,
    );
  }

  Duration? get duration {
    if (checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime);
  }

  bool get isActive => checkOutTime == null;
}

class FitnessMeasurement {
  final String id;
  final String memberId;
  final DateTime date;
  final double? weight; // in kg
  final double? height; // in cm
  final double? bodyFat; // percentage
  final double? muscleMass; // in kg
  final double? bmi;
  final double? chest; // in cm
  final double? waist; // in cm
  final double? hips; // in cm
  final double? biceps; // in cm
  final double? thighs; // in cm
  final String? notes;

  FitnessMeasurement({
    required this.id,
    required this.memberId,
    required this.date,
    this.weight,
    this.height,
    this.bodyFat,
    this.muscleMass,
    this.bmi,
    this.chest,
    this.waist,
    this.hips,
    this.biceps,
    this.thighs,
    this.notes,
  });

  FitnessMeasurement copyWith({
    String? id,
    String? memberId,
    DateTime? date,
    double? weight,
    double? height,
    double? bodyFat,
    double? muscleMass,
    double? bmi,
    double? chest,
    double? waist,
    double? hips,
    double? biceps,
    double? thighs,
    String? notes,
  }) {
    return FitnessMeasurement(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      bodyFat: bodyFat ?? this.bodyFat,
      muscleMass: muscleMass ?? this.muscleMass,
      bmi: bmi ?? this.bmi,
      chest: chest ?? this.chest,
      waist: waist ?? this.waist,
      hips: hips ?? this.hips,
      biceps: biceps ?? this.biceps,
      thighs: thighs ?? this.thighs,
      notes: notes ?? this.notes,
    );
  }
}

class FitnessGoal {
  final String id;
  final String memberId;
  final String title;
  final String description;
  final DateTime targetDate;
  final DateTime createdAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final Map<String, dynamic> targetMetrics; // e.g., {'weight': 70.0, 'bodyFat': 15.0}

  FitnessGoal({
    required this.id,
    required this.memberId,
    required this.title,
    required this.description,
    required this.targetDate,
    DateTime? createdAt,
    this.isCompleted = false,
    this.completedAt,
    Map<String, dynamic>? targetMetrics,
  }) :
    createdAt = createdAt ?? DateTime.now(),
    targetMetrics = targetMetrics ?? {};

  FitnessGoal copyWith({
    String? id,
    String? memberId,
    String? title,
    String? description,
    DateTime? targetDate,
    DateTime? createdAt,
    bool? isCompleted,
    DateTime? completedAt,
    Map<String, dynamic>? targetMetrics,
  }) {
    return FitnessGoal(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      targetMetrics: targetMetrics ?? Map<String, dynamic>.from(this.targetMetrics),
    );
  }
}

// GymRepository interface is provided by data layer in `gym_repository.dart`.

class GymProvider extends ChangeNotifier {
  final GymRepository? repository;
  final String? businessId;
  String? _businessId;
  final INotificationService? notificationService;

  final List<Member> members = [];
  final List<Trainer> trainers = [];
  final List<MembershipPlan> plans = [];
  final List<ClassSession> classes = [];
  final List<Booking> bookings = [];
  final List<PaymentRecord> payments = [];
  final List<Equipment> equipment = [];
  final List<AttendanceRecord> attendanceRecords = [];
  final List<FitnessMeasurement> measurements = [];
  final List<FitnessGoal> goals = [];

  GymProvider({this.repository, this.businessId, this.notificationService}) {
    // ensure internal business id is initialized when provided
    _businessId = businessId;
    // Load data from repository if available
    _initFromRepository();
  }

  /// Current business id in use (may be provided via constructor or via setBusinessId)
  String? get currentBusinessId => _businessId ?? businessId;

  /// Set business id and attempt to reload repository-backed data
  void setBusinessId(String businessId) {
    if (_businessId != null && _businessId == businessId) return;
    _businessId = businessId;
    try {
      if (repository != null) _initFromRepository();
    } catch (_) {}
    notifyListeners();
  }



  Future<void> _initFromRepository() async {
    if (repository == null) return;
    DateTime parseDate(dynamic v) {
      return parseTimestamp(v);
    }

    try {
      final remoteMembers = await repository!.fetchMembers();
      members.clear();
      members.addAll(remoteMembers.map((m) => Member(
            id: m['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: (m['name'] ?? '') as String,
            email: (m['email'] ?? '') as String,
            phone: (m['phone'] ?? '') as String,
            joinedAt: parseDate(m['joinedAt']),
          )));

      final remoteTrainers = await repository!.fetchTrainers();
      trainers.clear();
      trainers.addAll(remoteTrainers.map((t) => Trainer(
            id: t['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: (t['name'] ?? '') as String,
            specialty: (t['specialty'] ?? '') as String,
          )));

      final remoteClasses = await repository!.fetchClasses();
      classes.clear();
      classes.addAll(remoteClasses.map((c) => ClassSession(
            id: c['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: (c['title'] ?? '') as String,
            trainerId: (c['trainerId'] ?? '') as String,
            start: parseDate(c['start']),
            end: parseDate(c['end']),
            capacity: (c['capacity'] ?? 20) as int,
            bookedMemberIds: List<String>.from(
                (c['bookedMemberIds'] ?? []) as List<dynamic>),
          )));

      final remoteBookings = await repository!.fetchBookings();
      bookings.clear();
      bookings.addAll(remoteBookings.map((b) => Booking(
            id: b['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            memberId: (b['memberId'] ?? '') as String,
            classId: (b['classId'] ?? '') as String,
            bookedAt: parseDate(b['bookedAt']),
          )));

      // Load membership plans if repository supports it
      try {
        final remotePlans = await repository!.fetchPlans();
        plans.clear();
        int _toInt(dynamic v) {
          if (v == null) return 1;
          if (v is int) return v;
          if (v is String) return int.tryParse(v) ?? 1;
          if (v is num) return v.toInt();
          return 1;
        }

        double _toDouble(dynamic v) {
          if (v == null) return 0.0;
          if (v is double) return v;
          if (v is int) return v.toDouble();
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v) ?? 0.0;
          return 0.0;
        }

        List<String> _toFeatureList(dynamic v) {
          if (v == null) return [];
          if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          if (v is String) return v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          return [];
        }

        plans.addAll(remotePlans.map((p) => MembershipPlan(
              id: p['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: (p['name'] ?? p['title'] ?? '') as String,
              pricePerMonth: _toDouble(p['price'] ?? p['pricePerMonth'] ?? p['monthlyPrice']),
              durationMonths: _toInt(p['durationMonths'] ?? p['duration_months'] ?? p['duration'] ?? 1),
              features: _toFeatureList(p['features'] ?? p['featuresList'] ?? p['featureList']),
              isActive: (p['isActive'] ?? p['active'] ?? true) as bool,
            )));
      } catch (e) {
        // ignore if plans not implemented
      }

      // Load payments if repository supports it
      try {
        final remotePayments = await repository!.fetchPayments();
        payments.clear();
        payments.addAll(remotePayments
            .map((p) => PaymentRecord.fromJson(Map<String, dynamic>.from(p))));
      } catch (_) {
        // ignore if not implemented
      }

      // Load equipment if repository supports it
      try {
        final remoteEquipment = await repository!.fetchEquipment();
        equipment.clear();
        equipment.addAll(remoteEquipment.map((e) => Equipment(
              id: e['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: (e['name'] ?? '') as String,
              category: (e['category'] ?? 'General') as String,
              status: (e['status'] ?? 'available') as String,
              lastMaintenance: e['lastMaintenance'] != null ? parseDate(e['lastMaintenance']) : null,
              nextMaintenance: e['nextMaintenance'] != null ? parseDate(e['nextMaintenance']) : null,
              notes: e['notes'] as String?,
            )));
      } catch (_) {
        // ignore if equipment not implemented
      }

      // Load attendance records if repository supports it
      try {
        final remoteAttendance = await repository!.fetchAttendanceRecords();
        attendanceRecords.clear();
        attendanceRecords.addAll(remoteAttendance.map((a) => AttendanceRecord(
              id: a['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              memberId: (a['memberId'] ?? '') as String,
              checkInTime: parseDate(a['checkInTime']),
              checkOutTime: a['checkOutTime'] != null ? parseDate(a['checkOutTime']) : null,
              notes: a['notes'] as String?,
            )));
      } catch (_) {
        // ignore if attendance not implemented
      }

      notifyListeners();
    } catch (e) {
      // ignore repository errors for now
    }
  }

  /// Refresh data from repository
  Future<void> refresh() async {
    if (repository == null) return;
    await _initFromRepository();
  }

  // Members
  void addMember(Member m) {
    members.add(m);
    if (repository != null) {
      repository!.saveMember({
        'name': m.name,
        'email': m.email,
        'phone': m.phone,
        'joinedAt': m.joinedAt.toIso8601String(),
        'membershipPlanId': m.membershipPlanId,
        'membershipExpiry': m.membershipExpiry?.toIso8601String(),
      });
    }
    notifyListeners();
  }

  // Plans: CRUD helpers
  Map<String, dynamic> _planToMap(MembershipPlan p) {
    return {
      'id': p.id,
      'name': p.name,
      'price': p.pricePerMonth,
      'durationMonths': p.durationMonths,
      'features': p.features,
      'isActive': p.isActive,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> addPlan(MembershipPlan p) async {
    // Local optimistic update
    plans.add(p);
    notifyListeners();
    if (repository != null) {
      try {
        await repository!.savePlan(_planToMap(p));
        await _initFromRepository();
      } catch (e) {
        debugPrint('[GymProvider] Failed to save plan: $e');
      }
    }
  }

  Future<void> updatePlan(MembershipPlan p) async {
    final idx = plans.indexWhere((x) => x.id == p.id);
    if (idx != -1) plans[idx] = p;
    notifyListeners();
    if (repository != null) {
      try {
        await repository!.updatePlan(p.id, _planToMap(p));
        await _initFromRepository();
      } catch (e) {
        debugPrint('[GymProvider] Failed to update plan: $e');
      }
    }
  }

  Future<void> deletePlan(String id) async {
    plans.removeWhere((p) => p.id == id);
    notifyListeners();
    if (repository != null) {
      try {
        await repository!.deletePlan(id);
        await _initFromRepository();
      } catch (e) {
        debugPrint('[GymProvider] Failed to delete plan: $e');
      }
    }
  }

  Future<void> updateMember(Member m) async {
    final index = members.indexWhere((x) => x.id == m.id);
    if (index == -1) return;
    members[index] = m;
    if (repository != null) {
      await repository!.updateMember(m.id, {
        'name': m.name,
        'email': m.email,
        'phone': m.phone,
        'membershipPlanId': m.membershipPlanId,
        'membershipExpiry': m.membershipExpiry?.toIso8601String(),
      });
    }
    notifyListeners();
  }

  Future<void> deleteMember(String memberId) async {
    members.removeWhere((m) => m.id == memberId);
    if (repository != null) {
      await repository!.deleteMember(memberId);
    }
    notifyListeners();
  }

  Future<void> assignMembership(
      String memberId, String planId, int durationMonths) async {
    final m = members.firstWhere((x) => x.id == memberId,
        orElse: () => throw Exception('Member not found'));
    m.membershipPlanId = planId;
    m.membershipExpiry =
        DateTime.now().add(Duration(days: 30 * durationMonths));
    await updateMember(m);
    // Optionally record a payment when assigning a plan (not enforcing)
    try {
      final plan = plans.firstWhere((p) => p.id == planId,
          orElse: () =>
              MembershipPlan(id: planId, name: 'Plan', pricePerMonth: 0.0));
      await recordPayment(memberId, plan.pricePerMonth * durationMonths, 'card',
          planId: planId, note: 'Subscription purchase');
    } catch (_) {}
    // Schedule expiry notifications using admin-configured thresholds
    try {
      if (businessId != null && m.membershipExpiry != null) {
        final expiry = m.membershipExpiry!;
        final svc = notificationService ?? NotificationService.instance;
        final thresholds = await svc.getDaysBeforeThresholds();
        for (final days in thresholds) {
          try {
            await svc.scheduleExpiryAlert(
              businessId: businessId!,
              memberId: m.id,
              memberName: m.name,
              expiry: expiry,
              daysBefore: days,
            );
          } catch (_) {
            // continue scheduling other thresholds even if one fails
          }
        }
      }
    } catch (_) {}
  }

  Future<void> recordPayment(String memberId, double amount, String method,
      {String? planId, String? note, String currency = 'NGN'}) async {
    final payment = PaymentRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      memberId: memberId,
      amount: amount,
      currency: currency,
      method: method,
      timestamp: DateTime.now(),
      note: note,
      planId: planId,
    );
    payments.insert(0, payment);
    if (repository != null) {
      await repository!.savePayment(payment.toJson());
    }
    notifyListeners();
  }

  void checkIn(String memberId) {
    final m = members.firstWhere((x) => x.id == memberId,
        orElse: () => throw Exception('Member not found'));
    // For demo, we'll just mark active
    m.active = true;
    notifyListeners();
  }

  // Classes
  void bookClass(String memberId, String classId) {
    final cls = classes.firstWhere((c) => c.id == classId);
    if (cls.bookedMemberIds.length >= cls.capacity) {
      throw Exception('Class full');
    }
    if (cls.bookedMemberIds.contains(memberId)) return;
    cls.bookedMemberIds.add(memberId);
    final booking = Booking(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        memberId: memberId,
        classId: classId);
    bookings.add(booking);
    if (repository != null) {
      repository!.saveBooking({
        'memberId': booking.memberId,
        'classId': booking.classId,
        'bookedAt': booking.bookedAt.toIso8601String(),
      });
    }
    notifyListeners();
  }

  // Trainers
  void addTrainer(Trainer t) {
    trainers.add(t);
    if (repository != null) {
      repository!.saveTrainer({
        'name': t.name,
        'specialty': t.specialty,
      });
    }
    notifyListeners();
  }

  void updateTrainer(int index, Trainer t) {
    if (index >= 0 && index < trainers.length) {
      trainers[index] = t;
      if (repository != null) {
        repository!.updateTrainer(t.id, {
          'name': t.name,
          'specialty': t.specialty,
        });
      }
      notifyListeners();
    }
  }

  void removeTrainerById(String id) {
    trainers.removeWhere((t) => t.id == id);
    if (repository != null) {
      repository!.deleteTrainer(id);
    }
    notifyListeners();
  }

  List<ClassSession> upcomingClasses() {
    final now = DateTime.now();
    return classes.where((c) => c.start.isAfter(now)).toList();
  }

  // Equipment Management
  void addEquipment(Equipment eq) {
    equipment.add(eq);
    if (repository != null) {
      repository!.saveEquipment({
        'name': eq.name,
        'category': eq.category,
        'status': eq.status,
        'lastMaintenance': eq.lastMaintenance?.toIso8601String(),
        'nextMaintenance': eq.nextMaintenance?.toIso8601String(),
        'notes': eq.notes,
      });
    }
    notifyListeners();
  }

  void updateEquipment(Equipment eq) {
    final index = equipment.indexWhere((e) => e.id == eq.id);
    if (index != -1) {
      equipment[index] = eq;
      if (repository != null) {
        repository!.updateEquipment(eq.id, {
          'name': eq.name,
          'category': eq.category,
          'status': eq.status,
          'lastMaintenance': eq.lastMaintenance?.toIso8601String(),
          'nextMaintenance': eq.nextMaintenance?.toIso8601String(),
          'notes': eq.notes,
        });
      }
      notifyListeners();
    }
  }

  void deleteEquipment(String equipmentId) {
    equipment.removeWhere((e) => e.id == equipmentId);
    if (repository != null) {
      repository!.deleteEquipment(equipmentId);
    }
    notifyListeners();
  }

  List<Equipment> getEquipmentByStatus(String status) {
    return equipment.where((e) => e.status == status).toList();
  }

  List<Equipment> getEquipmentNeedingMaintenance() {
    final now = DateTime.now();
    return equipment.where((e) =>
        e.nextMaintenance != null &&
        e.nextMaintenance!.isBefore(now.add(const Duration(days: 7)))).toList();
  }

  // Attendance Management
  void checkInMember(String memberId) {
    // Check if member is already checked in
    final existingRecord = attendanceRecords.firstWhere(
      (record) => record.memberId == memberId && record.isActive,
      orElse: () => AttendanceRecord(id: '', memberId: '', checkInTime: DateTime.now()),
    );

    if (existingRecord.id.isNotEmpty) {
      throw Exception('Member is already checked in');
    }

    final record = AttendanceRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      memberId: memberId,
      checkInTime: DateTime.now(),
    );

    attendanceRecords.add(record);

    // Update member active status
    final member = members.firstWhere((m) => m.id == memberId);
    member.active = true;

    if (repository != null) {
      repository!.saveAttendanceRecord({
        'memberId': record.memberId,
        'checkInTime': record.checkInTime.toIso8601String(),
      });
    }

    notifyListeners();
  }

  void checkOutMember(String recordId) {
    final recordIndex = attendanceRecords.indexWhere((r) => r.id == recordId);
    if (recordIndex == -1) return;

    final record = attendanceRecords[recordIndex];
    final updatedRecord = record.copyWith(checkOutTime: DateTime.now());

    attendanceRecords[recordIndex] = updatedRecord;

    // Update member active status
    final member = members.firstWhere((m) => m.id == record.memberId);
    member.active = false;

    if (repository != null) {
      repository!.updateAttendanceRecord(recordId, {
        'checkOutTime': updatedRecord.checkOutTime!.toIso8601String(),
      });
    }

    notifyListeners();
  }

  List<AttendanceRecord> getAttendanceRecordsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return attendanceRecords.where((record) =>
        record.checkInTime.isAfter(startOfDay) &&
        record.checkInTime.isBefore(endOfDay)).toList();
  }

  List<AttendanceRecord> getActiveAttendanceRecords() {
    return attendanceRecords.where((record) => record.isActive).toList();
  }

  Duration getTotalAttendanceTimeForMember(String memberId, {DateTime? startDate, DateTime? endDate}) {
    final records = attendanceRecords.where((record) {
      if (record.memberId != memberId) return false;
      if (startDate != null && record.checkInTime.isBefore(startDate)) return false;
      if (endDate != null && record.checkInTime.isAfter(endDate)) return false;
      return record.checkOutTime != null;
    }).toList();

    return records.fold(Duration.zero, (total, record) => total + (record.duration ?? Duration.zero));
  }

  int getAttendanceCountForMember(String memberId, {DateTime? startDate, DateTime? endDate}) {
    return attendanceRecords.where((record) {
      if (record.memberId != memberId) return false;
      if (startDate != null && record.checkInTime.isBefore(startDate)) return false;
      if (endDate != null && record.checkInTime.isAfter(endDate)) return false;
      return true;
    }).length;
  }

  // Fitness Measurements
  void addMeasurement(FitnessMeasurement measurement) {
    measurements.add(measurement);
    if (repository != null) {
      repository!.saveMeasurement({
        'memberId': measurement.memberId,
        'date': measurement.date.toIso8601String(),
        'weight': measurement.weight,
        'height': measurement.height,
        'bodyFat': measurement.bodyFat,
        'muscleMass': measurement.muscleMass,
        'bmi': measurement.bmi,
        'chest': measurement.chest,
        'waist': measurement.waist,
        'hips': measurement.hips,
        'biceps': measurement.biceps,
        'thighs': measurement.thighs,
        'notes': measurement.notes,
      });
    }
    notifyListeners();
  }

  void updateMeasurement(FitnessMeasurement measurement) {
    final index = measurements.indexWhere((m) => m.id == measurement.id);
    if (index != -1) {
      measurements[index] = measurement;
      if (repository != null) {
        repository!.updateMeasurement(measurement.id, {
          'memberId': measurement.memberId,
          'date': measurement.date.toIso8601String(),
          'weight': measurement.weight,
          'height': measurement.height,
          'bodyFat': measurement.bodyFat,
          'muscleMass': measurement.muscleMass,
          'bmi': measurement.bmi,
          'chest': measurement.chest,
          'waist': measurement.waist,
          'hips': measurement.hips,
          'biceps': measurement.biceps,
          'thighs': measurement.thighs,
          'notes': measurement.notes,
        });
      }
      notifyListeners();
    }
  }

  void removeMeasurement(String id) {
    measurements.removeWhere((m) => m.id == id);
    if (repository != null) {
      repository!.deleteMeasurement(id);
    }
    notifyListeners();
  }

  List<FitnessMeasurement> getMeasurementsForMember(String memberId) {
    return measurements.where((m) => m.memberId == memberId).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Most recent first
  }

  FitnessMeasurement? getLatestMeasurementForMember(String memberId) {
    final memberMeasurements = getMeasurementsForMember(memberId);
    return memberMeasurements.isNotEmpty ? memberMeasurements.first : null;
  }

  // Fitness Goals
  void addGoal(FitnessGoal goal) {
    goals.add(goal);
    if (repository != null) {
      repository!.saveGoal({
        'memberId': goal.memberId,
        'title': goal.title,
        'description': goal.description,
        'targetDate': goal.targetDate.toIso8601String(),
        'createdAt': goal.createdAt.toIso8601String(),
        'isCompleted': goal.isCompleted,
        'completedAt': goal.completedAt?.toIso8601String(),
        'targetMetrics': goal.targetMetrics,
      });
    }
    notifyListeners();
  }

  void updateGoal(FitnessGoal goal) {
    final index = goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      goals[index] = goal;
      if (repository != null) {
        repository!.updateGoal(goal.id, {
          'memberId': goal.memberId,
          'title': goal.title,
          'description': goal.description,
          'targetDate': goal.targetDate.toIso8601String(),
          'createdAt': goal.createdAt.toIso8601String(),
          'isCompleted': goal.isCompleted,
          'completedAt': goal.completedAt?.toIso8601String(),
          'targetMetrics': goal.targetMetrics,
        });
      }
      notifyListeners();
    }
  }

  void removeGoal(String id) {
    goals.removeWhere((g) => g.id == id);
    if (repository != null) {
      repository!.deleteGoal(id);
    }
    notifyListeners();
  }

  List<FitnessGoal> getGoalsForMember(String memberId) {
    return goals.where((g) => g.memberId == memberId).toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate)); // Soonest first
  }

  List<FitnessGoal> getActiveGoalsForMember(String memberId) {
    return getGoalsForMember(memberId).where((g) => !g.isCompleted).toList();
  }

  List<FitnessGoal> getCompletedGoalsForMember(String memberId) {
    return getGoalsForMember(memberId).where((g) => g.isCompleted).toList();
  }

  List<FitnessGoal> getOverdueGoals() {
    final now = DateTime.now();
    return goals.where((g) => !g.isCompleted && g.targetDate.isBefore(now)).toList();
  }
}

