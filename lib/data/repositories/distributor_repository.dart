import '../../services/managecare_api_client.dart';

class DistributorRepository {
  DistributorRepository({ManagecareApiClient? api})
      : _api = api ?? ManagecareApiClient.instance;

  final ManagecareApiClient _api;

  Future<void> recordDistributorSale({
    required String businessId,
    required String distributorId,
    required String distributorName,
    required String productId,
    required String productName,
    required num quantity,
    required num unitPrice,
    num discountPercent = 0,
    String? salesRepId,
    String? salesRepName,
    String? notes,
  }) async {
    if (businessId.isEmpty || distributorId.isEmpty || productId.isEmpty) {
      throw Exception('businessId, distributorId, and productId are required');
    }
    if (quantity <= 0) {
      throw Exception('quantity must be greater than zero');
    }

    await _api.post('/api/distributors/$businessId/sales', body: {
      'distributorId': distributorId,
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discountPercent': discountPercent,
      'salesRepId': salesRepId,
      'salesRepName': salesRepName,
      'notes': notes,
    });
  }

  Future<List<Map<String, dynamic>>> getDistributors(String businessId) async {
    if (businessId.isEmpty) return [];
    final response = await _api.get('/api/distributors/$businessId');
    return ((response['data'] as List?) ?? [])
        .map((row) {
          final data = Map<String, dynamic>.from(row as Map);
          return {
            'id': data['id'],
            'name': data['name'],
            'contactPerson': data['contact_person'],
            'phone': data['phone'],
            'email': data['email'],
            'address': data['address'],
            'notes': data['notes'],
            'createdAt': data['created_at'],
          };
        })
        .toList();
  }

  Future<String> addDistributor({
    required String businessId,
    required String name,
    String? contactPerson,
    String? phone,
    String? notes,
  }) async {
    if (businessId.isEmpty || name.trim().isEmpty) {
      throw Exception('businessId and name are required');
    }

    final response = await _api.post('/api/distributors/$businessId', body: {
      'name': name.trim(),
      'contactPerson': contactPerson,
      'phone': phone,
      'notes': notes,
    });
    return Map<String, dynamic>.from(response as Map)['id'].toString();
  }

  Future<List<Map<String, dynamic>>> getDistributorSales(
    String businessId, {
    String? distributorId,
  }) async {
    if (businessId.isEmpty) return [];
    final response = await _api.get(
      '/api/distributors/$businessId/sales',
      query: {if (distributorId != null) 'distributorId': distributorId},
    );
    return ((response['data'] as List?) ?? [])
        .map((row) {
          final data = Map<String, dynamic>.from(row as Map);
          return {
            'id': data['id'],
            'businessId': data['business_id'],
            'saleId': data['sale_id'],
            'distributorId': data['distributor_id'],
            'distributorName': data['distributor_name'],
            'productId': data['product_id'],
            'productName': data['product_name'],
            'quantity': data['quantity'],
            'unitPrice': data['unit_price'],
            'discountPercent': data['discount_percent'],
            'discountedUnitPrice': data['discounted_unit_price'],
            'totalAmount': data['total_amount'],
            'salesRepId': data['sales_rep_id'],
            'salesRepName': data['sales_rep_name'],
            'notes': data['notes'],
            'status': data['status'],
            'createdAt': data['created_at'],
          };
        })
        .toList();
  }
}
