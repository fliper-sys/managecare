import 'package:cloud_firestore/cloud_firestore.dart';
import 'salon_repository.dart';

/// Firestore implementation for Salon repository
class SalonRepositoryImpl implements SalonRepository {
  final FirebaseFirestore _firestore;

  SalonRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Book a new appointment
  @override
  Future<void> bookAppointment(Map<String, dynamic> appointment) async {
    try {
      final data = {
        ...appointment,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (appointment['id'] != null && appointment['id'].isNotEmpty) {
        // Update existing appointment
        await _firestore
            .collection('salon_appointments')
            .doc(appointment['id'])
            .set(data, SetOptions(merge: true));
      } else {
        // Create new appointment
        await _firestore.collection('salon_appointments').add(data);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch appointments for a business
  @override
  Future<List<Map<String, dynamic>>> fetchAppointments(
      String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('salon_appointments')
          .where('businessId', isEqualTo: businessId)
          .orderBy('appointmentDate', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all stylists/staff for a business
  @override
  Future<List<Map<String, dynamic>>> fetchStylists(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('salon_staff')
          .where('businessId', isEqualTo: businessId)
          .where('role', isEqualTo: 'stylist')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch available services for a business
  Future<List<Map<String, dynamic>>> fetchServices(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('salon_services')
          .where('businessId', isEqualTo: businessId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Add or update a service
  Future<void> saveService(
      String businessId, Map<String, dynamic> service) async {
    try {
      final data = {
        ...service,
        'businessId': businessId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (service['id'] != null && service['id'].isNotEmpty) {
        await _firestore
            .collection('salon_services')
            .doc(service['id'])
            .set(data, SetOptions(merge: true));
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('salon_services').add(data);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel an appointment
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await _firestore
          .collection('salon_appointments')
          .doc(appointmentId)
          .update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Mark appointment as completed
  Future<void> completeAppointment(String appointmentId) async {
    try {
      await _firestore
          .collection('salon_appointments')
          .doc(appointmentId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get stylist availability
  Future<Map<String, dynamic>?> getStylistAvailability(String stylistId) async {
    try {
      final doc =
          await _firestore.collection('salon_staff').doc(stylistId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get appointments for a specific date
  Future<List<Map<String, dynamic>>> getAppointmentsForDate(
      String businessId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('salon_appointments')
          .where('businessId', isEqualTo: businessId)
          .where('appointmentDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('appointmentDate')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get income report for date range
  Future<Map<String, dynamic>> getIncomeReport(
      String businessId, DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _firestore
          .collection('salon_appointments')
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'completed')
          .where('appointmentDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('appointmentDate',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double totalIncome = 0;
      int totalAppointments = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalIncome += (data['price'] as num?)?.toDouble() ?? 0;
        totalAppointments++;
      }

      return {
        'totalIncome': totalIncome,
        'totalAppointments': totalAppointments,
        'averagePerAppointment':
            totalAppointments > 0 ? totalIncome / totalAppointments : 0,
      };
    } catch (e) {
      rethrow;
    }
  }
}

