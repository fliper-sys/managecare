import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../data/local/database_helper.dart';
import '../../core/config/supabase_config.dart';

/// Supabase/Postgres-backed implementation of InventoryRepository.
/// Replaces InventoryRepositoryImpl (Firebase Firestore).
class InventoryRepositorySupabase implements InventoryRepository {
  final Dio _http;
  final SupabaseClient _supabase;
  final DatabaseHelper _dbHelper;

  InventoryRepositorySupabase({
    Dio? http,
    SupabaseClient? supabase,
    DatabaseHelper? dbHelper,
  })  : _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _supabase = supabase ?? Supabase.instance.client,
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  String? get _accessToken => _supabase.auth.currentSession?.accessToken;
  Map<String, dynamic> get _headers => {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      if (data is String) return data;
    } catch (_) {}
    return e.message ?? 'Unknown error';
  }

  @override
  Future<dynamic> addInventory(Map<String, dynamic> inventoryData) async {
    try {
      final businessId = inventoryData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');
      final response = await _http.post(
        '/inventory/$businessId',
        data: _buildPayload(inventoryData),
        options: Options(headers: _headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Failed to add inventory: ${_extractError(e)}');
    }
  }

  @override
  Future<void> updateInventory(String inventoryId, Map<String, dynamic> inventoryData) async {
    try {
      final businessId = inventoryData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');
      await _http.put(
        '/inventory/$businessId/$inventoryId',
        data: _buildPayload(inventoryData),
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update inventory: ${_extractError(e)}');
    }
  }

  @override
  Future<void> deleteInventory(String inventoryId) async {
    throw UnimplementedError('Use deleteInventoryForBusiness(businessId, inventoryId) instead');
  }

  Future<void> deleteInventoryForBusiness(String businessId, String inventoryId) async {
    try {
      await _http.delete(
        '/inventory/$businessId/$inventoryId',
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to delete inventory: ${_extractError(e)}');
    }
  }

  @override
  Future<List<dynamic>> getInventory(String businessId,
      {Map<String, dynamic>? filters, String? storeId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (filters != null) {
        if (filters.containsKey('category')) queryParams['category'] = filters['category'];
        if (filters.containsKey('search')) queryParams['search'] = filters['search'];
        if (filters.containsKey('lowStock')) queryParams['lowStock'] = filters['lowStock'] == true ? 'true' : 'false';
        if (filters.containsKey('isActive')) queryParams['isActive'] = filters['isActive'] == true ? 'true' : 'false';
      }
      if (storeId != null && storeId.isNotEmpty) queryParams['storeId'] = storeId;
      final response = await _http.get(
        '/inventory/$businessId',
        queryParameters: queryParams,
        options: Options(headers: _headers),
      );
      return (response.data['data'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch inventory: ${_extractError(e)}');
    }
  }

  @override
  Future<dynamic> getInventoryById(String inventoryId) async {
    try {
      final businesses = await _supabase
          .from('business_members')
          .select('business_id')
          .eq('user_id', _supabase.auth.currentUser?.id ?? '')
          .eq('is_active', true);
      for (final b in businesses) {
        try {
          final response = await _http.get(
            '/inventory/${b['business_id']}/$inventoryId',
            options: Options(headers: _headers),
          );
          if (response.statusCode == 200) return response.data;
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<dynamic>> getLowStockItems(String businessId, {String? storeId}) async {
    return getInventory(businessId, filters: {'lowStock': true}, storeId: storeId);
  }

  @override
  Future<List<dynamic>> getExpiredItems(String businessId, {String? storeId}) async {
    try {
      final queryParams = <String, dynamic>{'expired': 'true'};
      if (storeId != null && storeId.isNotEmpty) queryParams['storeId'] = storeId;
      final response = await _http.get(
        '/inventory/$businessId',
        queryParameters: queryParams,
        options: Options(headers: _headers),
      );
      final data = (response.data['data'] as List?) ?? [];
      return data.where((item) {
        final expiry = item['expiry_date'];
        if (expiry == null) return false;
        final expiryDate = DateTime.tryParse(expiry.toString());
        return expiryDate != null && expiryDate.isBefore(DateTime.now());
      }).toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch expired items: ${_extractError(e)}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchInventory({String? businessId, String? storeId}) async {
    if (businessId == null || businessId.isEmpty) throw Exception('Business ID is required');
    final result = await getInventory(businessId, storeId: storeId);
    return result.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<dynamic>> expiredItems(String businessId) async {
    return getExpiredItems(businessId);
  }

  @override
  Stream<List<Map<String, dynamic>>> streamInventory(String businessId, {String? storeId}) {
    // Client-side filtering since eq() is not available on SupabaseStreamBuilder in this SDK version
    return _supabase
        .from('inventory')
        .stream(primaryKey: ['id'])
        .map((maps) {
          var filtered = maps.where((m) => m['business_id'] == businessId);
          if (storeId != null && storeId.isNotEmpty) {
            filtered = filtered.where((m) => m['store_id'] == storeId);
          }
          return filtered.map((m) => Map<String, dynamic>.from(m)).toList();
        });
  }

  @override
  Future<void> addHistoryEntry(String businessId, String inventoryId, Map<String, dynamic> entry) async {
    try {
      await _http.post(
        '/inventory/$businessId/$inventoryId/history',
        data: entry,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to add history entry: ${_extractError(e)}');
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> streamInventoryHistory(String businessId, String inventoryId) {
    return _supabase
        .from('inventory_history')
        .stream(primaryKey: ['id'])
        .map((maps) {
          var filtered = maps.where((m) => m['business_id'] == businessId && m['inventory_id'] == inventoryId);
          return filtered.map((m) => Map<String, dynamic>.from(m)).toList();
        });
  }

  @override
  Future<int> assignAllInventoryToStore(String businessId, String storeId) async {
    try {
      final response = await _http.patch(
        '/inventory/$businessId/assign-store',
        data: {'store_id': storeId},
        options: Options(headers: _headers),
      );
      return (response.data['updated'] as int?) ?? 0;
    } on DioException catch (e) {
      throw Exception('Failed to assign inventory to store: ${_extractError(e)}');
    }
  }

  @override
  Future<void> syncInventoryToFirestore(Map<String, dynamic> inventoryData) async {
    try {
      final businessId = inventoryData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId required');
      final inventoryId = inventoryData['id']?.toString() ?? '';
      if (inventoryId.isNotEmpty) {
        try {
          final checkResponse = await _http.get(
            '/inventory/$businessId/$inventoryId',
            options: Options(headers: _headers),
          );
          if (checkResponse.statusCode == 200) {
            await _http.put(
              '/inventory/$businessId/$inventoryId',
              data: _buildPayload(inventoryData),
              options: Options(headers: _headers),
            );
            return;
          }
        } catch (_) {}
      }
      final payload = _buildPayload(inventoryData);
      payload['id'] = inventoryId.isNotEmpty ? inventoryId : null;
      await _http.post(
        '/inventory/$businessId',
        data: payload,
        options: Options(headers: _headers),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> recordBakeryResupply({
    required String businessId,
    required String inventoryId,
    required num quantity,
    String? bakerId,
    String? bakerName,
    String? notes,
    String? performedById,
    String? performedByName,
    num? expectedProductionAmount,
    num? actualProductionAmount,
    String? productionUnit,
    String? productionItemName,
  }) async {
    try {
      await _http.post(
        '/inventory/$businessId/$inventoryId/resupply',
        data: {
          'quantity': quantity,
          'baker_id': bakerId,
          'baker_name': bakerName,
          'notes': notes,
          'performed_by_id': performedById,
          'performed_by_name': performedByName,
          'expected_production_amount': expectedProductionAmount,
          'actual_production_amount': actualProductionAmount,
          'production_unit': productionUnit,
          'production_item_name': productionItemName,
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to record bakery resupply: ${_extractError(e)}');
    }
  }

  Map<String, dynamic> _buildPayload(Map<String, dynamic> data) {
    return {
      'name': data['name'],
      'sku': data['sku'],
      'barcode': data['barcode'],
      'category': data['category'],
      'description': data['description'],
      'unit_price': data['unitPrice'] ?? data['unit_price'] ?? 0,
      'cost_price': data['costPrice'] ?? data['cost_price'] ?? 0,
      'quantity': data['quantity'] ?? 0,
      'stock': data['stock'],
      'min_stock_level': data['minStockLevel'] ?? data['min_stock_level'] ?? 0,
      'unit': data['unit'] ?? 'pcs',
      'expiry_date': data['expiryDate'] ?? data['expiry_date'],
      'store_id': data['storeId'] ?? data['store_id'],
      'is_active': data['isActive'] ?? data['is_active'] ?? true,
    };
  }
}
