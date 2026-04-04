import 'package:flutter/material.dart';
import '../data/models/booking_model.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/booking_repository_impl.dart';

class BookingProvider extends ChangeNotifier {
  final BookingRepository _repo;

  BookingProvider({BookingRepository? repository}) : _repo = repository ?? BookingRepositoryImpl();

  Future<String> createBooking({
    required String businessId,
    required Booking booking,
    bool requirePayment = false,
  }) async {
    try {
      final id = await _repo.createBooking(
        businessId: businessId,
        booking: booking,
        requirePayment: requirePayment,
      );
      return id;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> checkAvailability({required String businessId, required String unitId, required DateTime checkIn, required DateTime checkOut}) async {
    return await _repo.checkAvailability(businessId: businessId, unitId: unitId, checkIn: checkIn, checkOut: checkOut);
  }

  Future<List<Booking>> fetchBookings({required String businessId, String? apartmentId, String? unitId}) async {
    return await _repo.fetchBookings(businessId: businessId, apartmentId: apartmentId, unitId: unitId);
  }

  Future<void> updateBookingStatus({required String businessId, required String bookingId, required String status, Map<String, dynamic>? updates}) async {
    await _repo.updateBookingStatus(businessId: businessId, bookingId: bookingId, status: status, updates: updates);
  }

  Future<void> cancelBooking({required String businessId, required String bookingId, String? reason}) async {
    await _repo.cancelBooking(businessId: businessId, bookingId: bookingId, reason: reason);
  }
}
