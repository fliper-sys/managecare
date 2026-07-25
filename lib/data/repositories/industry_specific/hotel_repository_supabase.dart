import 'package:supabase_flutter/supabase_flutter.dart';
import 'hotel_repository.dart';

/// Supabase/Postgres-backed HotelRepository.
class HotelRepositorySupabase implements HotelRepository {
  final SupabaseClient _supabase;

  HotelRepositorySupabase({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchRooms(String businessId) async {
    final result = await _supabase
        .from('hotel_rooms')
        .select('*')
        .eq('business_id', businessId)
        .order('room_number');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> room) async {
    final data = Map<String, dynamic>.from(room)..remove('id');
    final response = await _supabase
        .from('hotel_rooms')
        .insert({...data, 'business_id': data['business_id'] ?? data['businessId']})
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<Map<String, dynamic>> createBooking(
      Map<String, dynamic> booking) async {
    final data = Map<String, dynamic>.from(booking)..remove('id');
    final response = await _supabase
        .from('hotel_reservations')
        .insert(data)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGuests(String businessId) async {
    final result = await _supabase
        .from('customers')
        .select('*')
        .eq('business_id', businessId)
        .eq('category', 'hotel_guest')
        .order('name');
    return result.map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReservations(
      String businessId) async {
    final result = await _supabase
        .from('hotel_reservations')
        .select('*, hotel_rooms(*)')
        .eq('business_id', businessId)
        .eq('status', 'active')
        .order('check_in', ascending: false)
        .limit(100);
    return result.map((m) {
      final map = Map<String, dynamic>.from(m);
      // Rename room_number to roomName for app compatibility
      if (map['hotel_rooms'] != null) {
        map['roomName'] = map['hotel_rooms']['room_number'];
      }
      return map;
    }).toList();
  }

  @override
  Future<void> updateReservation(String businessId, String reservationId,
      Map<String, dynamic> updates) async {
    final data = Map<String, dynamic>.from(updates)..remove('id');
    await _supabase
        .from('hotel_reservations')
        .update(data)
        .eq('id', reservationId);
  }

  @override
  Future<void> cancelReservation(String businessId, String reservationId,
      {String? reason}) async {
    final data = <String, dynamic>{'status': 'cancelled'};
    if (reason != null && reason.isNotEmpty) {
      data['cancel_reason'] = reason;
    }
    await _supabase
        .from('hotel_reservations')
        .update(data)
        .eq('id', reservationId);
  }

  @override
  Future<void> syncReservations(
      String businessId, List<Map<String, dynamic>> reservations) async {
    for (final res in reservations) {
      final id = res['id'] as String?;
      final data = Map<String, dynamic>.from(res)..remove('id');
      if (id != null && id.isNotEmpty) {
        await _supabase
            .from('hotel_reservations')
            .upsert({...data, 'id': id});
      } else {
        await _supabase
            .from('hotel_reservations')
            .insert({...data, 'business_id': businessId});
      }
    }
  }
}

