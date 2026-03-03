abstract class SalesRepository {
  Future<List<Map<String, dynamic>>> fetchSales({String? businessId, String? storeId});
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> sale);
  Future<void> syncSales();
  Future<Map<String, dynamic>?> getReceipt(String id);
  Future<void> syncSaleToFirestore(Map<String, dynamic> saleData);
}

