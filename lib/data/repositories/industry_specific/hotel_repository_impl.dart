import 'hotel_repository.dart';
import '../../../services/managecare_api_client.dart';

/// Supabase/Postgres-backed implementation of `HotelRepository`.
/// Replaces the Firestore version. Talks to the custom backend's
/// `/api/hotel/*` routes via the shared [ManagecareApiClient].
class HotelRepositoryImpl implements HotelRepository {
  final ManagecareApiClient _api;

  HotelRepositoryImpl({ManagecareApiClient? api}) : _api = api ?? ManagecareApiClient.instance;

  Map<String, dynamic> _roomRowToJson(Map<String, dynamic> row) => {
        'id': row['id'],
        'number': row['number'],
        'type': row['type'],
        'capacity': row['capacity'],
        'pricePerNight': row['price_per_night'],
        'halfDayPrice': row['half_day_price'],
        'status': row['status'],
        'emoji': row['emoji'],
        'amenities': row['amenities'],
        'images': row['images'],
        'priceIntervals': row['price_intervals'],
        'floor': row['floor'],
        'rating': row['rating'],
        'size': row['size'],
        'bedSize': row['bed_size'],
        'extraDetails': row['extra_details'],
        'halfDayHours': row['half_day_hours'],
        'fullDayCheckoutTime': row['full_day_checkout_time'],
      };

  Map<String, dynamic> _reservationRowToJson(Map<String, dynamic> row) => {
        'id': row['id'],
        'roomId': row['room_id'],
        'roomNumber': row['room_number'],
        'guestName': row['guest_name'],
        'guestEmail': row['guest_email'],
        'guestPhone': row['guest_phone'],
        'guestSex': row['guest_sex'],
        'occupantCount': row['occupant_count'],
        'guestAddress': row['guest_address'],
        'guestNationality': row['guest_nationality'],
        'guestIdType': row['guest_id_type'],
        'guestIdNumber': row['guest_id_number'],
        'nextOfKinName': row['next_of_kin_name'],
        'nextOfKinPhone': row['next_of_kin_phone'],
        'nextOfKinRelationship': row['next_of_kin_relationship'],
        'bookingSource': row['booking_source'],
        'companyName': row['company_name'],
        'vehiclePlateNumber': row['vehicle_plate_number'],
        'vehicleMake': row['vehicle_make'],
        'vehicleModel': row['vehicle_model'],
        'vehicleYear': row['vehicle_year'],
        'vehicleColor': row['vehicle_color'],
        'paymentMethod': row['payment_method'],
        'mixedPaymentNote': row['mixed_payment_note'],
        'stayDurationType': row['stay_duration_type'],
        'estimatedArrivalAt': row['estimated_arrival_at'],
        'checkIn': row['check_in'],
        'checkOut': row['check_out'],
        'adults': row['adults'],
        'children': row['children'],
        'status': row['status'],
        'totalPrice': row['total_price'],
        'specialRequests': row['special_requests'],
        'paymentStatus': row['payment_status'],
        'cancelReason': row['cancel_reason'],
        'createdAt': row['created_at'],
      };

  @override
  Future<List<Map<String, dynamic>>> fetchRooms(String businessId) async {
    try {
      final response = await _api.get('/api/hotel/$businessId/rooms');
      final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      return rows.map(_roomRowToJson).toList();
    } catch (e) {
      // Log and return empty list so provider can use sample data
      // ignore: avoid_print
      print('Error fetching rooms: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> room) async {
    try {
      final businessId = room['businessId'] as String?;
      if (businessId == null) throw Exception('businessId is required');
      final response = await _api.post('/api/hotel/$businessId/rooms', body: {
        'number': room['number'],
        'type': room['type'],
        'capacity': room['capacity'],
        'price_per_night': room['pricePerNight'],
        'half_day_price': room['halfDayPrice'],
        'status': room['status'],
        'emoji': room['emoji'],
        'amenities': room['amenities'],
        'images': room['images'],
        'price_intervals': room['priceIntervals'],
        'floor': room['floor'],
        'size': room['size'],
        'bed_size': room['bedSize'],
        'extra_details': room['extraDetails'],
        'half_day_hours': room['halfDayHours'],
        'full_day_checkout_time': room['fullDayCheckoutTime'],
      });
      return _roomRowToJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      // ignore: avoid_print
      print('Error creating room: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> booking) async {
    try {
      final businessId = booking['businessId'] as String?;
      if (businessId == null) throw Exception('businessId is required');
      final response = await _api.post('/api/hotel/$businessId/reservations', body: {
        'room_id': booking['roomId'],
        'room_number': booking['roomNumber'],
        'guest_name': booking['guestName'],
        'guest_email': booking['guestEmail'],
        'guest_phone': booking['guestPhone'],
        'guest_sex': booking['guestSex'],
        'occupant_count': booking['occupantCount'],
        'guest_address': booking['guestAddress'],
        'guest_nationality': booking['guestNationality'],
        'guest_id_type': booking['guestIdType'],
        'guest_id_number': booking['guestIdNumber'],
        'next_of_kin_name': booking['nextOfKinName'],
        'next_of_kin_phone': booking['nextOfKinPhone'],
        'next_of_kin_relationship': booking['nextOfKinRelationship'],
        'booking_source': booking['bookingSource'],
        'company_name': booking['companyName'],
        'vehicle_plate_number': booking['vehiclePlateNumber'],
        'vehicle_make': booking['vehicleMake'],
        'vehicle_model': booking['vehicleModel'],
        'vehicle_year': booking['vehicleYear'],
        'vehicle_color': booking['vehicleColor'],
        'payment_method': booking['paymentMethod'],
        'mixed_payment_note': booking['mixedPaymentNote'],
        'stay_duration_type': booking['stayDurationType'],
        'estimated_arrival_at': booking['estimatedArrivalAt'],
        'check_in': booking['checkIn'],
        'check_out': booking['checkOut'],
        'adults': booking['adults'],
        'children': booking['children'],
        'status': booking['status'],
        'total_price': booking['totalPrice'],
        'special_requests': booking['specialRequests'],
        'payment_status': booking['paymentStatus'],
      });
      return _reservationRowToJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      // ignore: avoid_print
      print('Error creating booking: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGuests(String businessId) async {
    // Not called by HotelProvider today (it computes guest profiles from
    // reservations client-side) - kept for interface parity.
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReservations(String businessId) async {
    try {
      final response = await _api.get('/api/hotel/$businessId/reservations');
      final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      return rows.map(_reservationRowToJson).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching reservations: $e');
      return [];
    }
  }

  @override
  Future<void> updateReservation(String businessId, String reservationId, Map<String, dynamic> updates) async {
    try {
      final payload = <String, dynamic>{};
      if (updates.containsKey('status')) payload['status'] = updates['status'];
      if (updates.containsKey('paymentStatus')) payload['payment_status'] = updates['paymentStatus'];
      if (updates.containsKey('paymentMethod')) payload['payment_method'] = updates['paymentMethod'];
      if (updates.containsKey('mixedPaymentNote')) payload['mixed_payment_note'] = updates['mixedPaymentNote'];
      if (updates.containsKey('stayDurationType')) payload['stay_duration_type'] = updates['stayDurationType'];
      if (updates.containsKey('estimatedArrivalAt')) payload['estimated_arrival_at'] = updates['estimatedArrivalAt'];
      if (updates.containsKey('checkOut')) payload['check_out'] = updates['checkOut'];
      if (updates.containsKey('totalPrice')) payload['total_price'] = updates['totalPrice'];
      if (updates.containsKey('specialRequests')) payload['special_requests'] = updates['specialRequests'];
      if (updates.containsKey('cancelReason')) payload['cancel_reason'] = updates['cancelReason'];
      await _api.put('/api/hotel/$businessId/reservations/$reservationId', body: payload);
    } catch (e) {
      // ignore: avoid_print
      print('Error updating reservation: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelReservation(String businessId, String reservationId, {String? reason}) async {
    try {
      await _api.put('/api/hotel/$businessId/reservations/$reservationId', body: {
        'status': 'cancelled',
        if (reason != null && reason.isNotEmpty) 'cancel_reason': reason,
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error cancelling reservation: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncReservations(String businessId, List<Map<String, dynamic>> reservations) async {
    // Not called by HotelProvider today - kept for interface parity.
  }
}
