/// Abstract customer repository
abstract class CustomerRepository {
  Future<dynamic> addCustomer(Map<String, dynamic> customerData);
  Future<void> updateCustomer(
      String customerId, Map<String, dynamic> customerData);
  Future<void> deleteCustomer(String customerId);
  Future<List<dynamic>> getCustomers(String businessId,
      {Map<String, dynamic>? filters});
  Future<dynamic> getCustomerById(String customerId);
  Future<List<dynamic>> getTopCustomers(String businessId);
  Future<List<Map<String, dynamic>>> fetchCustomers({String? businessId});
  Future<void> syncCustomerToFirestore(Map<String, dynamic> customerData);
}

