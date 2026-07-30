import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../data/local/database_helper.dart';
import '../../core/config/supabase_config.dart';

/// Supabase/Postgres-backed implementation of CustomerRepository.
///
/// Replaces CustomerRepositoryImpl (Firebase Firestore).
class CustomerRepositorySupabase implements CustomerRepository {
  final Dio _http;
  final SupabaseClient _supabase;
  final DatabaseHelper _dbHelper;

  CustomerRepositorySupabase({
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
  Future<dynamic> addCustomer(Map<String, dynamic> customerData) async {
    try {
      final businessId = customerData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');

      final response = await _http.post(
        '/customers/$businessId',
        data: _buildPayload(customerData),
        options: Options(headers: _headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Failed to add customer: ${_extractError(e)}');
    }
  }

  @override
  Future<void> updateCustomer(
      String customerId, Map<String, dynamic> customerData) async {
    try {
      final businessId = customerData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');

      await _http.put(
        '/customers/$businessId/$customerId',
        data: _buildPayload(customerData),
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update customer: ${_extractError(e)}');
    }
  }

  @override
  Future<void> deleteCustomer(String customerId) async {
    throw UnimplementedError(
        'Use deleteCustomerForBusiness(businessId, customerId) instead');
  }

  Future<void> deleteCustomerForBusiness(
      String businessId, String customerId) async {
    try {
      await _http.delete(
        '/customers/$businessId/$customerId',
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to delete customer: ${_extractError(e)}');
    }
  }

  @override
  Future<List<dynamic>> getCustomers(String businessId,
      {Map<String, dynamic>? filters}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (filters != null) {
        if (filters.containsKey('search')) {
          queryParams['search'] = filters['search'];
        }
        if (filters.containsKey('isActive')) {
          queryParams['isActive'] =
              filters['isActive'] == true ? 'true' : 'false';
        }
        if (filters.containsKey('startDate') && filters['startDate'] != null) {
          queryParams['startDate'] = filters['startDate'];
        }
        if (filters.containsKey('endDate') && filters['endDate'] != null) {
          queryParams['endDate'] = filters['endDate'];
        }
        if (filters.containsKey('limit') && filters['limit'] != null) {
          queryParams['limit'] = filters['limit'];
        }
      }

      final response = await _http.get(
        '/customers/$businessId',
        queryParameters: queryParams,
        options: Options(headers: _headers),
      );
      return (response.data['data'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch customers: ${_extractError(e)}');
    }
  }

  @override
  Future<dynamic> getCustomerById(String customerId) async {
    try {
      final businesses = await _supabase
          .from('business_members')
          .select('business_id')
          .eq('user_id', _supabase.auth.currentUser?.id ?? '')
          .eq('is_active', true);

      for (final b in businesses) {
        try {
          final response = await _http.get(
            '/customers/${b['business_id']}/$customerId',
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
  Future<List<dynamic>> getTopCustomers(String businessId) async {
    try {
      final response = await _http.get(
        '/customers/$businessId/top',
        options: Options(headers: _headers),
      );
      return (response.data as List?) ?? [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch top customers: ${_extractError(e)}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCustomers(
      {String? businessId}) async {
    if (businessId == null || businessId.isEmpty) {
      throw Exception('Business ID is required');
    }
    final result = await getCustomers(businessId);
    return result.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> syncCustomerToFirestore(
      Map<String, dynamic> customerData) async {
    // Syncs to Postgres API, not Firestore
    try {
      final businessId = customerData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId required');
      final customerId = customerData['id']?.toString() ?? '';

      if (customerId.isNotEmpty) {
        try {
          final checkResponse = await _http.get(
            '/customers/$businessId/$customerId',
            options: Options(headers: _headers),
          );
          if (checkResponse.statusCode == 200) {
            await _http.put(
              '/customers/$businessId/$customerId',
              data: _buildPayload(customerData),
              options: Options(headers: _headers),
            );
            return;
          }
        } catch (_) {}
      }

      final payload = _buildPayload(customerData);
      payload['id'] = customerId.isNotEmpty ? customerId : null;
      await _http.post(
        '/customers/$businessId',
        data: payload,
        options: Options(headers: _headers),
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _buildPayload(Map<String, dynamic> data) {
    return {
      'name': data['name'],
      'email': data['email'],
      'phone': data['phone'],
      'address': data['address'],
      'city': data['city'],
      'state': data['state'],
      'is_active': data['isActive'] ?? data['is_active'] ?? true,
    };
  }
}

