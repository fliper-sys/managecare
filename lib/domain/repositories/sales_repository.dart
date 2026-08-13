/// Abstract sales repository
abstract class SalesRepository {
  Future<dynamic> createSale(Map<String, dynamic> saleData);
  Future<void> updateSale(String saleId, Map<String, dynamic> saleData);
  Future<void> deleteSale(String saleId);
  Future<List<dynamic>> getSales(String businessId,
      {Map<String, dynamic>? filters});
  Future<dynamic> getSaleById(String saleId);
  Future<List<Map<String, dynamic>>> fetchSales(
      {String? businessId, String? storeId, DateTime? start, DateTime? end, int? limit});
  Future<void> syncSales();
  Future<Map<String, dynamic>?> getReceipt(String id);
  Future<void> syncSaleToFirestore(Map<String, dynamic> saleData);

  // Offline support methods
  Future<String> createSaleOffline(Map<String, dynamic> saleData);
  Future<List<Map<String, dynamic>>> getPendingOfflineSales();
  Future<void> markSaleAsSynced(String saleId);
  Future<void> deleteOfflineSale(String saleId);
}

