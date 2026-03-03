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
      {String? planId, String? note, String currency = 'USD'}) async {
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
}

