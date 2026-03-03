import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Gym and fitness center business logic
class GymBusinessLogic {
  final FirebaseFirestore _firestore;

  GymBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get membership details for a member
  Future<MembershipDetails> getMembershipDetails(
    String businessId,
    String memberId,
  ) async {
    try {
      final snap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('members')
          .doc(memberId)
          .get();

      if (!snap.exists) {
        return MembershipDetails.empty();
      }

      final data = snap.data() ?? {};

      return MembershipDetails(
        memberId: memberId,
        memberName: data['name'] ?? 'Unknown',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        membershipType: data['membershipType'] ?? 'standard',
        joinDate: data['joinDate'] != null ? parseTimestamp(data['joinDate']) : DateTime.now(),
        renewalDate: data['renewalDate'] != null ? parseTimestamp(data['renewalDate']) : null,
        monthlyCost: (data['monthlyCost'] as num?)?.toDouble() ?? 0,
        status: data['status'] ?? 'active',
        classesPerMonth: data['classesPerMonth'] ?? 0,
        personalTrainerSessions: data['personalTrainerSessions'] ?? 0,
      );
    } catch (e) {
      print('Error getting membership details: $e');
      return MembershipDetails.empty();
    }
  }

  /// Get available class schedule
  Future<List<ClassSchedule>> getClassSchedule(
    String businessId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('classes')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .orderBy('date')
          .orderBy('startTime')
          .get();

      final classes = <ClassSchedule>[];

      for (var doc in snap.docs) {
        final data = doc.data();

        // Get enrollment count
        final enrollmentSnap = await _firestore
            .collection('gym')
            .doc(businessId)
            .collection('classEnrollments')
            .where('classId', isEqualTo: doc.id)
            .get();

        classes.add(ClassSchedule(
          classId: doc.id,
          className: data['name'] ?? 'Unknown',
          instructorName: data['instructor'] ?? 'Unknown',
          date: data['date'] != null ? parseTimestamp(data['date']) : DateTime.now(),
          startTime: data['startTime'] ?? '00:00',
          endTime: data['endTime'] ?? '01:00',
          capacity: data['capacity'] ?? 0,
          enrolledCount: enrollmentSnap.docs.length,
          classType: data['type'] ?? 'general',
          level: data['level'] ?? 'beginner',
        ));
      }

      return classes;
    } catch (e) {
      print('Error getting class schedule: $e');
      return [];
    }
  }

  /// Calculate member billing
  Future<BillingCycle> calculateMemberBilling(
    String businessId,
    String memberId,
    DateTime month,
  ) async {
    try {
      // Get member details
      final memberSnap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('members')
          .doc(memberId)
          .get();

      if (!memberSnap.exists) {
        return BillingCycle.empty();
      }

      final memberData = memberSnap.data() ?? {};
      double baseMonthlyCost =
          (memberData['monthlyCost'] as num?)?.toDouble() ?? 0;

      // Calculate personal training charges
      final ptSessionsSnap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('personalTrainingSessions')
          .where('memberId', isEqualTo: memberId)
          .where('date',
              isGreaterThanOrEqualTo: DateTime(month.year, month.month, 1))
          .where('date',
              isLessThanOrEqualTo: DateTime(month.year, month.month + 1, 0))
          .where('completed', isEqualTo: true)
          .get();

      double ptCharges = ptSessionsSnap.docs.length * 50; // $50 per session

      // Calculate class upgrade charges
      final classesSnap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('classEnrollments')
          .where('memberId', isEqualTo: memberId)
          .where('date',
              isGreaterThanOrEqualTo: DateTime(month.year, month.month, 1))
          .where('date',
              isLessThanOrEqualTo: DateTime(month.year, month.month + 1, 0))
          .get();

      double additionalClassCharges = 0;
      int membershipClassLimit = memberData['classesPerMonth'] ?? 0;
      int classesAttended = classesSnap.docs.length;

      if (classesAttended > membershipClassLimit) {
        additionalClassCharges = (classesAttended - membershipClassLimit) *
            15; // $15 per extra class
      }

      final totalBilling = baseMonthlyCost + ptCharges + additionalClassCharges;

      return BillingCycle(
        memberId: memberId,
        billingMonth: month,
        baseMonthlyCost: baseMonthlyCost,
        personalTrainingCharges: ptCharges,
        additionalClassCharges: additionalClassCharges,
        totalBilling: totalBilling,
        ptSessionsAttended: ptSessionsSnap.docs.length,
        classesAttended: classesAttended,
      );
    } catch (e) {
      print('Error calculating billing: $e');
      return BillingCycle.empty();
    }
  }

  /// Analyze member engagement and retention
  Future<MemberEngagementAnalysis> analyzeMemberEngagement(
    String businessId,
    String memberId,
    int monthsBack,
  ) async {
    try {
      // Get member joining date
      final memberSnap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('members')
          .doc(memberId)
          .get();

      if (!memberSnap.exists) {
        return MemberEngagementAnalysis.empty();
      }

      // Calculate check-in history
      final checkinsSnap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('checkins')
          .where('memberId', isEqualTo: memberId)
          .where('date',
              isGreaterThanOrEqualTo:
                  DateTime.now().subtract(Duration(days: monthsBack * 30)))
          .get();

      int totalCheckIns = checkinsSnap.docs.length;
      double avgCheckinsPerWeek = totalCheckIns / (monthsBack * 4.3);

      // Calculate class participation
      final classParticipationSnap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('classEnrollments')
          .where('memberId', isEqualTo: memberId)
          .where('date',
              isGreaterThanOrEqualTo:
                  DateTime.now().subtract(Duration(days: monthsBack * 30)))
          .get();

      int classesAttended = classParticipationSnap.docs.length;

      // Calculate pt session usage
      final ptUsageSnap = await _firestore
          .collection('gym')
          .doc(businessId)
          .collection('personalTrainingSessions')
          .where('memberId', isEqualTo: memberId)
          .where('completed', isEqualTo: true)
          .where('date',
              isGreaterThanOrEqualTo:
                  DateTime.now().subtract(Duration(days: monthsBack * 30)))
          .get();

      int ptSessionsUsed = ptUsageSnap.docs.length;

      // Determine retention status
      final lastCheckIn = checkinsSnap.docs.isNotEmpty
          ? parseTimestamp(checkinsSnap.docs.last.data()['date']) ??
              DateTime.now()
          : DateTime.now();

      final daysSinceLastCheckIn =
          DateTime.now().difference(lastCheckIn).inDays;
      String retentionStatus = daysSinceLastCheckIn <= 7
          ? 'active'
          : daysSinceLastCheckIn <= 30
              ? 'at-risk'
              : 'inactive';

      return MemberEngagementAnalysis(
        memberId: memberId,
        totalCheckIns: totalCheckIns,
        avgCheckinsPerWeek: avgCheckinsPerWeek,
        classesAttended: classesAttended,
        ptSessionsUsed: ptSessionsUsed,
        daysSinceLastCheckIn: daysSinceLastCheckIn,
        retentionStatus: retentionStatus,
        engagementScore: (avgCheckinsPerWeek * 20 +
                classesAttended * 5 +
                ptSessionsUsed * 10)
            .toInt(),
      );
    } catch (e) {
      print('Error analyzing engagement: $e');
      return MemberEngagementAnalysis.empty();
    }
  }
}

class MembershipDetails {
  final String memberId;
  final String memberName;
  final String email;
  final String phone;
  final String membershipType;
  final DateTime joinDate;
  final DateTime? renewalDate;
  final double monthlyCost;
  final String status;
  final int classesPerMonth;
  final int personalTrainerSessions;

  MembershipDetails({
    required this.memberId,
    required this.memberName,
    required this.email,
    required this.phone,
    required this.membershipType,
    required this.joinDate,
    this.renewalDate,
    required this.monthlyCost,
    required this.status,
    required this.classesPerMonth,
    required this.personalTrainerSessions,
  });

  factory MembershipDetails.empty() {
    return MembershipDetails(
      memberId: '',
      memberName: '',
      email: '',
      phone: '',
      membershipType: '',
      joinDate: DateTime.now(),
      monthlyCost: 0,
      status: 'inactive',
      classesPerMonth: 0,
      personalTrainerSessions: 0,
    );
  }
}

class ClassSchedule {
  final String classId;
  final String className;
  final String instructorName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int capacity;
  final int enrolledCount;
  final String classType;
  final String level;

  ClassSchedule({
    required this.classId,
    required this.className,
    required this.instructorName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.enrolledCount,
    required this.classType,
    required this.level,
  });

  int get spotsAvailable => capacity - enrolledCount;
  double get occupancyPercentage =>
      capacity > 0 ? (enrolledCount / capacity * 100) : 0;
}

class BillingCycle {
  final String memberId;
  final DateTime billingMonth;
  final double baseMonthlyCost;
  final double personalTrainingCharges;
  final double additionalClassCharges;
  final double totalBilling;
  final int ptSessionsAttended;
  final int classesAttended;

  BillingCycle({
    required this.memberId,
    required this.billingMonth,
    required this.baseMonthlyCost,
    required this.personalTrainingCharges,
    required this.additionalClassCharges,
    required this.totalBilling,
    required this.ptSessionsAttended,
    required this.classesAttended,
  });

  factory BillingCycle.empty() {
    return BillingCycle(
      memberId: '',
      billingMonth: DateTime.now(),
      baseMonthlyCost: 0,
      personalTrainingCharges: 0,
      additionalClassCharges: 0,
      totalBilling: 0,
      ptSessionsAttended: 0,
      classesAttended: 0,
    );
  }
}

class MemberEngagementAnalysis {
  final String memberId;
  final int totalCheckIns;
  final double avgCheckinsPerWeek;
  final int classesAttended;
  final int ptSessionsUsed;
  final int daysSinceLastCheckIn;
  final String retentionStatus;
  final int engagementScore;

  MemberEngagementAnalysis({
    required this.memberId,
    required this.totalCheckIns,
    required this.avgCheckinsPerWeek,
    required this.classesAttended,
    required this.ptSessionsUsed,
    required this.daysSinceLastCheckIn,
    required this.retentionStatus,
    required this.engagementScore,
  });

  factory MemberEngagementAnalysis.empty() {
    return MemberEngagementAnalysis(
      memberId: '',
      totalCheckIns: 0,
      avgCheckinsPerWeek: 0,
      classesAttended: 0,
      ptSessionsUsed: 0,
      daysSinceLastCheckIn: 0,
      retentionStatus: 'unknown',
      engagementScore: 0,
    );
  }
}

