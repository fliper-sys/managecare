abstract class CustomerRepository {
  Future<List<Map<String, dynamic>>> fetchCustomers(String businessId);
  Future<Map<String, dynamic>> addCustomer(Map<String, dynamic> customer);
  Future<Map<String, dynamic>?> getCustomer(String id);
  Future<void> updateCustomer(String id, Map<String, dynamic> updates);
  Future<void> syncCustomerToFirestore(Map<String, dynamic> customerData);
}

