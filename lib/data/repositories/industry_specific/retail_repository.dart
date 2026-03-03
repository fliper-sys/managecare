abstract class RetailRepository {
  Future<List<Map<String, dynamic>>> fetchProducts(String businessId);
  Future<void> addProduct(Map<String, dynamic> product);
  Future<List<Map<String, dynamic>>> fetchSuppliers(String businessId);
}

