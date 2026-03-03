import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/datetime_utils.dart';

/// Salon-specific business logic (Appointments, Pricing, Services)
class SalonBusinessLogic {
  final FirebaseFirestore _firestore;

  SalonBusinessLogic({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get available time slots for a specific date
  Future<List<TimeSlot>> getAvailableTimeSlots(
    String businessId,
    DateTime date,
    String serviceId,
  ) async {
    try {
      // Get service duration
      final serviceDoc = await _firestore
          .collection('salon')
          .doc(businessId)
          .collection('services')
          .doc(serviceId)
          .get();

      final durationMinutes = serviceDoc.data()?['durationMinutes'] ?? 30;

      // Get existing appointments for the date
      final nextDay = date.add(const Duration(days: 1));
      final appointmentsSnap = await _firestore
          .collection('salon')
          .doc(businessId)
          .collection('appointments')
          .where('date', isGreaterThanOrEqualTo: date)
          .where('date', isLessThan: nextDay)
          .where('status', isNotEqualTo: 'cancelled')
          .get();

      final bookedSlots = <String>{};
      for (var doc in appointmentsSnap.docs) {
        final data = doc.data();
        bookedSlots.add(data['timeSlot'] ?? '');
      }

      // Generate available slots
      final slots = <TimeSlot>[];
      final businessHours = await _getBusinessHours(businessId);
      final openHour = businessHours['openHour'] ?? 9;
      final closeHour = businessHours['closeHour'] ?? 17;

      for (int hour = openHour; hour < closeHour; hour++) {
        for (int minute = 0; minute < 60; minute += 15) {
          final slotString =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          if (!bookedSlots.contains(slotString)) {
            slots.add(TimeSlot(
              time: slotString,
              isAvailable: true,
              durationMinutes: durationMinutes,
            ));
          }
        }
      }

      return slots;
    } catch (e) {
      print('Error getting available time slots: $e');
      return [];
    }
  }

  /// Get stylist availability
  Future<List<StylistAvailability>> getStylistAvailability(
    String businessId,
    String serviceId,
    DateTime date,
  ) async {
    try {
      final stylistSnap = await _firestore
          .collection('salon')
          .doc(businessId)
          .collection('stylists')
          .where('services', arrayContains: serviceId)
          .get();

      final availability = <StylistAvailability>[];

      for (var stylistDoc in stylistSnap.docs) {
        final stylistData = stylistDoc.data();
        final nextDay = date.add(const Duration(days: 1));

        // Get appointments for this stylist
        final appointmentsSnap = await _firestore
            .collection('salon')
            .doc(businessId)
            .collection('appointments')
            .where('stylistId', isEqualTo: stylistDoc.id)
            .where('date', isGreaterThanOrEqualTo: date)
            .where('date', isLessThan: nextDay)
            .where('status', isNotEqualTo: 'cancelled')
            .get();

        final appointmentCount = appointmentsSnap.docs.length;

        availability.add(StylistAvailability(
          stylistId: stylistDoc.id,
          stylistName: stylistData['name'] ?? 'Unknown',
          appointmentCount: appointmentCount,
          rating: (stylistData['rating'] as num?)?.toDouble() ?? 4.5,
          isAvailable: appointmentCount < 8, // Max 8 appointments per day
        ));
      }

      return availability..sort((a, b) => b.rating.compareTo(a.rating));
    } catch (e) {
      print('Error getting stylist availability: $e');
      return [];
    }
  }

  /// Calculate appointment pricing
  Future<AppointmentPricing> calculateAppointmentPrice(
    String businessId,
    String serviceId,
    String? customerId,
  ) async {
    try {
      final serviceDoc = await _firestore
          .collection('salon')
          .doc(businessId)
          .collection('services')
          .doc(serviceId)
          .get();

      final basePrice = (serviceDoc.data()?['price'] as num?)?.toDouble() ?? 0;
      double discount = 0;

      // Check customer loyalty
      if (customerId != null) {
        final customerDoc = await _firestore
            .collection('salon')
            .doc(businessId)
            .collection('customers')
            .doc(customerId)
            .get();

        final visitCount = customerDoc.data()?['visitCount'] ?? 0;

        // Apply discount based on visits
        if (visitCount >= 10) {
          discount = basePrice * 0.15; // 15% for 10+ visits
        } else if (visitCount >= 5) {
          discount = basePrice * 0.10; // 10% for 5+ visits
        }
      }

      final finalPrice = basePrice - discount;

      return AppointmentPricing(
        basePrice: basePrice,
        discount: discount,
        finalPrice: finalPrice,
        duration: serviceDoc.data()?['durationMinutes'] ?? 30,
      );
    } catch (e) {
      print('Error calculating appointment price: $e');
      return AppointmentPricing(
        basePrice: 0,
        discount: 0,
        finalPrice: 0,
        duration: 30,
      );
    }
  }

  /// Get customer appointment history and preferences
  Future<CustomerSalonProfile> getCustomerProfile(
    String businessId,
    String customerId,
  ) async {
    try {
      final customerDoc = await _firestore
          .collection('salon')
          .doc(businessId)
          .collection('customers')
          .doc(customerId)
          .get();

      final appointmentsSnap = await _firestore
          .collection('salon')
          .doc(businessId)
          .collection('appointments')
          .where('customerId', isEqualTo: customerId)
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      final data = customerDoc.data();

      return CustomerSalonProfile(
        customerId: customerId,
        name: data?['name'] ?? 'Customer',
        email: data?['email'] ?? '',
        phone: data?['phone'] ?? '',
        visitCount: data?['visitCount'] ?? 0,
        totalSpent: (data?['totalSpent'] as num?)?.toDouble() ?? 0,
        preferredStylist: data?['preferredStylist'],
        preferredServices: List<String>.from(data?['preferredServices'] ?? []),
        lastVisit: data?['lastVisit'] != null ? parseTimestamp(data?['lastVisit']) : null,
        recentAppointments: appointmentsSnap.docs
            .map((doc) =>
                AppointmentSummary.fromMap({...doc.data(), 'id': doc.id}))
            .toList(),
      );
    } catch (e) {
      print('Error getting customer profile: $e');
      return CustomerSalonProfile(
        customerId: customerId,
        name: 'Customer',
        email: '',
        phone: '',
        visitCount: 0,
        totalSpent: 0,
        recentAppointments: [],
        preferredServices: [],
      );
    }
  }

  Future<Map<String, int>> _getBusinessHours(String businessId) async {
    try {
      final doc = await _firestore.collection('business').doc(businessId).get();
      final hours = doc.data()?['operatingHours'] ?? {};
      return {
        'openHour': hours['openHour'] ?? 9,
        'closeHour': hours['closeHour'] ?? 18,
      };
    } catch (e) {
      return {'openHour': 9, 'closeHour': 18};
    }
  }
}

class TimeSlot {
  final String time;
  final bool isAvailable;
  final int durationMinutes;

  TimeSlot({
    required this.time,
    required this.isAvailable,
    required this.durationMinutes,
  });
}

class StylistAvailability {
  final String stylistId;
  final String stylistName;
  final int appointmentCount;
  final double rating;
  final bool isAvailable;

  StylistAvailability({
    required this.stylistId,
    required this.stylistName,
    required this.appointmentCount,
    required this.rating,
    required this.isAvailable,
  });
}

class AppointmentPricing {
  final double basePrice;
  final double discount;
  final double finalPrice;
  final int duration;

  AppointmentPricing({
    required this.basePrice,
    required this.discount,
    required this.finalPrice,
    required this.duration,
  });
}

class CustomerSalonProfile {
  final String customerId;
  final String name;
  final String email;
  final String phone;
  final int visitCount;
  final double totalSpent;
  final String? preferredStylist;
  final List<String> preferredServices;
  final DateTime? lastVisit;
  final List<AppointmentSummary> recentAppointments;

  CustomerSalonProfile({
    required this.customerId,
    required this.name,
    required this.email,
    required this.phone,
    required this.visitCount,
    required this.totalSpent,
    this.preferredStylist,
    required this.preferredServices,
    this.lastVisit,
    required this.recentAppointments,
  });
}

class AppointmentSummary {
  final String id;
  final DateTime date;
  final String serviceName;
  final String stylistName;
  final double price;
  final String status;

  AppointmentSummary({
    required this.id,
    required this.date,
    required this.serviceName,
    required this.stylistName,
    required this.price,
    required this.status,
  });

  factory AppointmentSummary.fromMap(Map<String, dynamic> map) {
    return AppointmentSummary(
      id: map['id'] ?? '',
      date: parseTimestamp(map['date']),
      serviceName: map['serviceName'] ?? '',
      stylistName: map['stylistName'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      status: map['status'] ?? 'completed',
    );
  }
}

