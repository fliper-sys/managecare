abstract class RealEstateRepository {
  Future<List<Map<String, dynamic>>> fetchProperties(String businessId);
  Future<Map<String, dynamic>?> fetchPropertyById(String businessId, String id);
  Future<Map<String, dynamic>> saveProperty(
      String businessId, Map<String, dynamic> property);
  Future<void> deleteProperty(String businessId, String id);

  Future<List<Map<String, dynamic>>> fetchOwners(String businessId);
  Future<Map<String, dynamic>> saveOwner(
      String businessId, Map<String, dynamic> owner);

  // Bookings (viewings, inspections, etc.)
  Future<List<Map<String, dynamic>>> fetchBookings(String businessId);
  Future<Map<String, dynamic>> saveBooking(
      String businessId, Map<String, dynamic> booking);
  Future<void> deleteBooking(String businessId, String id);

  // Payments (rent, deposits)
  Future<List<Map<String, dynamic>>> fetchPayments(String businessId);
  Future<Map<String, dynamic>> savePayment(
      String businessId, Map<String, dynamic> payment);

  // Property documents (metadata stored here; file storage handled separately)
  Future<List<Map<String, dynamic>>> fetchDocuments(String businessId,
      {String? propertyId});
  Future<Map<String, dynamic>> saveDocument(
      String businessId, Map<String, dynamic> document);

  // Escrow and transaction workflows
  Future<List<Map<String, dynamic>>> fetchEscrows(String businessId);
  Future<Map<String, dynamic>> saveEscrow(
      String businessId, Map<String, dynamic> escrow);

  // Inventory related to properties (appliances, spare parts, keys, supplies)
  Future<List<Map<String, dynamic>>> fetchInventory(String businessId);
  Future<Map<String, dynamic>> saveInventoryItem(
      String businessId, Map<String, dynamic> item);
  Future<void> deleteInventoryItem(String businessId, String id);
}

