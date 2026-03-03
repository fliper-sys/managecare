abstract class HotelRepository {
  Future<List<Map<String, dynamic>>> fetchRooms(String businessId);
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> booking);
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> room);
  Future<List<Map<String, dynamic>>> fetchGuests(String businessId);

  /// Fetch reservations for the given business.
  Future<List<Map<String, dynamic>>> fetchReservations(String businessId);

  /// Sync reservations (batch write) for the given business.
  Future<void> syncReservations(
      String businessId, List<Map<String, dynamic>> reservations);
}

