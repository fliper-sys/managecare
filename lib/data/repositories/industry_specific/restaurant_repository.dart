abstract class RestaurantRepository {
  Future<List<Map<String, dynamic>>> fetchMenuItems(String businessId);
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order);
  Future<List<Map<String, dynamic>>> fetchReservations(String businessId);
}

