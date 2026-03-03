import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final FirebaseFirestore _firestore;

  AttendanceRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  @override
  Future<List<Map<String, dynamic>>> getAttendanceRecords(
    String businessId,
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('attendance')
          .where('businessId', isEqualTo: businessId)
          .where('workerId', isEqualTo: workerId);
      // Note: orderBy removed to avoid requiring composite index
      // Sorting is done client-side after retrieval

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList()
          .cast<Map<String, dynamic>>();

      // Sort by date descending on client side
      records.sort((a, b) {
        final aDate = (a['date'] as Timestamp?)?.toDate() ?? DateTime(1970);
        final bDate = (b['date'] as Timestamp?)?.toDate() ?? DateTime(1970);
        return bDate.compareTo(aDate); // Descending order
      });

      return records;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getAttendanceStats(
    String businessId,
    String workerId,
  ) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('attendance')
          .where('businessId', isEqualTo: businessId)
          .where('workerId', isEqualTo: workerId)
          .where('date', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();

      int totalDays = snapshot.docs.length;
      int presentDays =
          snapshot.docs.where((doc) => doc['status'] == 'present').length;
      int absentDays =
          snapshot.docs.where((doc) => doc['status'] == 'absent').length;
      int lateDays =
          snapshot.docs.where((doc) => doc['status'] == 'late').length;

      return {
        'totalDays': totalDays,
        'presentDays': presentDays,
        'absentDays': absentDays,
        'lateDays': lateDays,
        'attendanceRate': totalDays > 0 ? (presentDays / totalDays * 100) : 0,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> recordAttendance(
    String businessId,
    String workerId,
    Map<String, dynamic> record,
  ) async {
    try {
      await _firestore.collection('attendance').add({
        'businessId': businessId,
        'workerId': workerId,
        ...record,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateAttendance(
    String businessId,
    String recordId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore
          .collection('attendance')
          .doc(recordId)
          .update({...updates, 'updatedAt': DateTime.now()});
    } catch (e) {
      rethrow;
    }
  }
}

