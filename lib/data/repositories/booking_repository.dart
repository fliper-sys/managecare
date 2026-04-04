import '../models/booking_model.dart';

abstract class BookingRepository {
  /// Create a booking (should enforce availability server-side or via transaction)
  /// Returns bookingId on success.
  Future<String> createBooking({
    required String businessId,
    required Booking booking,
    bool requirePayment = false,
  });

  /// Check if unit is available for the date range (no overlapping confirmed/pending/checkedIn bookings)
  Future<bool> checkAvailability({required String businessId, required String unitId, required DateTime checkIn, required DateTime checkOut});

  Future<void> cancelBooking({required String businessId, required String bookingId, String? reason});

  /// Fetch bookings for a business or apartment
  Future<List<Booking>> fetchBookings({required String businessId, String? apartmentId, String? unitId, int limit = 100});

  /// Fetch a single booking by id
  Future<Booking?> getBooking({required String businessId, required String bookingId});

  /// Update booking status and optionally payment fields
  Future<void> updateBookingStatus({required String businessId, required String bookingId, required String status, Map<String, dynamic>? updates});

  // Additional operations: attach receipts, query by user, etc.
}
