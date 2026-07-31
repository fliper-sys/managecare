import '../../services/managecare_api_client.dart';
import 'booking_repository.dart';
import '../models/booking_model.dart';

class BookingRepositoryImpl implements BookingRepository {
  final ManagecareApiClient _api;

  BookingRepositoryImpl({ManagecareApiClient? api})
      : _api = api ?? ManagecareApiClient.instance;

  @override
  Future<String> createBooking({
    required String businessId,
    required Booking booking,
    bool requirePayment = false,
  }) async {
    final response = await _api.post(
      '/api/apartments/$businessId/bookings',
      body: {
        ...booking.toApi(),
        'requirePayment': requirePayment,
      },
    );
    return response['id'].toString();
  }

  @override
  Future<bool> checkAvailability({required String businessId, required String unitId, required DateTime checkIn, required DateTime checkOut}) async {
    final response = await _api.get(
      '/api/apartments/$businessId/availability',
      query: {
        'unitId': unitId,
        'checkIn': checkIn.toUtc().toIso8601String(),
        'checkOut': checkOut.toUtc().toIso8601String(),
      },
    );
    return response['available'] == true;
  }

  @override
  Future<void> cancelBooking({required String businessId, required String bookingId, String? reason}) async {
    await _api.patch(
      '/api/apartments/$businessId/bookings/$bookingId',
      body: {
        'status': 'cancelled',
        'cancelReason': reason,
      },
    );
  }

  @override
  Future<List<Booking>> fetchBookings({required String businessId, String? apartmentId, String? unitId, int limit = 100}) async {
    final response = await _api.get(
      '/api/apartments/$businessId/bookings',
      query: {
        if (apartmentId != null) 'apartmentId': apartmentId,
        if (unitId != null) 'unitId': unitId,
        'limit': limit,
      },
    );
    return ((response['data'] as List?) ?? [])
        .map((row) => Booking.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<Booking?> getBooking({required String businessId, required String bookingId}) async {
    try {
      final response =
          await _api.get('/api/apartments/$businessId/bookings/$bookingId');
      return Booking.fromMap(Map<String, dynamic>.from(response as Map));
    } on ManagecareApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> updateBookingStatus({required String businessId, required String bookingId, required String status, Map<String, dynamic>? updates}) async {
    await _api.patch(
      '/api/apartments/$businessId/bookings/$bookingId',
      body: {
        'status': status,
        ...?updates,
      },
    );
  }
}
