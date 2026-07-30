import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../data/local/database_helper.dart';
import '../../core/config/supabase_config.dart';

/// Supabase/Postgres-backed implementation of SalesRepository.
///
/// Replaces the previous SalesRepositoryImpl which used Firebase Firestore.
/// Online operations go through the REST API at backend.managecare.info/api/sales.
/// Offline operations use the local SQLite database, synced via the sync service.
class SalesRepositorySupabase implements SalesRepository {
  final Dio _http;
  final SupabaseClient _supabase;
  final DatabaseHelper _dbHelper;

  SalesRepositorySupabase({
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

  // ===================== ONLINE OPERATIONS (REST API) =====================

  @override
  Future<dynamic> createSale(Map<String, dynamic> saleData) async {
    try {
      final businessId = saleData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');

      final response = await _http.post(
        '/sales/$businessId',
        data: saleData,
        options: Options(headers: _headers),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('Failed to create sale: ${_extractError(e)}');
    }
  }

  @override
  Future<void> updateSale(String saleId, Map<String, dynamic> saleData) async {
    try {
      final businessId = saleData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) throw Exception('businessId is required');

      await _http.put(
        '/sales/$businessId/$saleId',
        data: saleData,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update sale: ${_extractError(e)}');
    }
  }

  @override
  Future<void> deleteSale(String saleId) async {
    throw UnimplementedError(
      'deleteSale() requires businessId. Use deleteSaleForBusiness() instead.',
    );
  }

  /// Delete a sale with businessId context. The backend restores inventory
  /// and writes a `sale_deletions` audit row atomically as part of this call.
  Future<void> deleteSaleForBusiness(String businessId, String saleId,
      {String? reason}) async {
    try {
      await _http.delete(
        '/sales/$businessId/$saleId',
        data: reason != null ? {'reason': reason} : null,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to delete sale: ${_extractError(e)}');
    }
  }

  @override
  Future<List<dynamic>> getSales(String businessId,
      {Map<String, dynamic>? filters}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (filters != null) {
        if (filters.containsKey('storeId') && filters['storeId'] != null) {
          queryParams['storeId'] = filters['storeId'];
        }
        if (filters.containsKey('workerId') && filters['workerId'] != null) {
          queryParams['workerId'] = filters['workerId'];
        }
        if (filters.containsKey('startDate') && filters['startDate'] != null) {
          queryParams['startDate'] = filters['startDate'];
        }
        if (filters.containsKey('endDate') && filters['endDate'] != null) {
          queryParams['endDate'] = filters['endDate'];
        }
        if (filters.containsKey('status') && filters['status'] != null) {
          queryParams['status'] = filters['status'];
        }
        if (filters.containsKey('paymentMethod') &&
            filters['paymentMethod'] != null) {
          queryParams['paymentMethod'] = filters['paymentMethod'];
        }
        if (filters.containsKey('customerId') &&
            filters['customerId'] != null) {
          queryParams['customerId'] = filters['customerId'];
        }
      }

      final response = await _http.get(
        '/sales/$businessId',
        queryParameters: queryParams,
        options: Options(headers: _headers),
      );
      return (response.data['data'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception('Failed to fetch sales: ${_extractError(e)}');
    }
  }

  @override
  Future<dynamic> getSaleById(String saleId) async {
    try {
      final businesses = await _supabase
          .from('business_members')
          .select('business_id')
          .eq('user_id', _supabase.auth.currentUser?.id ?? '')
          .eq('is_active', true);

      for (final b in businesses) {
        try {
          final response = await _http.get(
            '/sales/${b['business_id']}/$saleId',
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
  Future<List<Map<String, dynamic>>> fetchSales({
    String? businessId,
    String? storeId,
    DateTime? start,
    DateTime? end,
  }) async {
    if (businessId == null || businessId.isEmpty) {
      throw Exception('Business ID is required to fetch sales');
    }

    try {
      final queryParams = <String, dynamic>{
        'limit': 500,
      };
      if (storeId != null && storeId.isNotEmpty) {
        queryParams['storeId'] = storeId;
      }
      if (start != null) {
        queryParams['startDate'] = start.toIso8601String();
      }
      if (end != null) {
        queryParams['endDate'] = end.toIso8601String();
      }

      final response = await _http.get(
        '/sales/$businessId',
        queryParameters: queryParams,
        options: Options(headers: _headers),
      );
      final data = (response.data['data'] as List?) ?? [];
      return data.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception('Failed to fetch sales: ${_extractError(e)}');
    }
  }

  @override
  Future<Map<String, dynamic>?> getReceipt(String id) async {
    final sale = await getSaleById(id);
    if (sale is Map<String, dynamic>) {
      return sale;
    }
    return null;
  }

  // ==================== SYNC (to Postgres API) ====================

  @override
  Future<void> syncSales() async {
    final pendingSales = await getPendingOfflineSales();
    for (final saleData in pendingSales) {
      final saleId = saleData['id']?.toString() ?? '';
      if (saleId.isEmpty) continue;
      try {
        await syncSaleToFirestore(saleData);
        await markSaleAsSynced(saleId);
      } catch (e) {
        print('[SalesRepositorySupabase] Failed to sync sale $saleId: $e');
      }
    }
  }

  @override
  Future<void> syncSaleToFirestore(Map<String, dynamic> saleData) async {
    // This syncs to the Postgres API, not Firestore
    try {
      final businessId = saleData['businessId']?.toString() ?? '';
      if (businessId.isEmpty) {
        throw Exception('Missing businessId — cannot sync');
      }

      final payload = _buildApiPayload(saleData);
      final saleId = saleData['id']?.toString() ?? '';

      if (saleId.isNotEmpty) {
        try {
          final checkResponse = await _http.get(
            '/sales/$businessId/$saleId',
            options: Options(headers: _headers),
          );
          if (checkResponse.statusCode == 200) {
            await _http.put(
              '/sales/$businessId/$saleId',
              data: payload,
              options: Options(headers: _headers),
            );
            return;
          }
        } catch (_) {
          // Sale doesn't exist, create below
        }
      }

      payload['id'] = saleId.isNotEmpty ? saleId : null;
      await _http.post(
        '/sales/$businessId',
        data: payload,
        options: Options(headers: _headers),
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _buildApiPayload(Map<String, dynamic> saleData) {
    final items = <Map<String, dynamic>>[];

    if (saleData['items'] is List) {
      for (final raw in saleData['items'] as List) {
        if (raw is Map) {
          items.add(Map<String, dynamic>.from(raw));
        }
      }
    }

    return {
      'customer_id': saleData['customerId']?.toString(),
      'store_id': saleData['storeId']?.toString(),
      'worker_id': saleData['workerId']?.toString(),
      'worker_name': saleData['workerName']?.toString(),
      'total_amount': (saleData['totalAmount'] ?? saleData['total'] ?? 0),
      'discount_amount': (saleData['discountAmount'] ?? saleData['discount'] ?? 0),
      'tax_amount': (saleData['taxAmount'] ?? saleData['tax'] ?? 0),
      'final_amount': (saleData['finalAmount'] ?? saleData['total'] ?? 0),
      'payment_method': saleData['paymentMethod']?.toString() ?? 'Cash',
      'status': saleData['status']?.toString() ?? 'completed',
      'notes': saleData['notes']?.toString(),
      'created_by': saleData['createdBy']?.toString() ?? '',
      'sale_type': saleData['saleType']?.toString() ?? 'retail',
      'items': items,
    };
  }

  // ==================== OFFLINE OPERATIONS (Local SQLite) ====================

  @override
  Future<String> createSaleOffline(Map<String, dynamic> saleData) async {
    try {
      final saleId = saleData['id']?.toString() ??
          'SALE-${DateTime.now().millisecondsSinceEpoch}';
      final businessId = saleData['businessId']?.toString() ?? '';
      final customerId = saleData['customerId']?.toString();
      final paymentMethod = saleData['paymentMethod']?.toString() ?? 'Cash';
      final status = saleData['status']?.toString() ?? 'completed';
      final notes = saleData['notes']?.toString();
      final createdBy =
          saleData['createdBy']?.toString() ?? saleData['createdById']?.toString() ?? '';
      final createdAt = DateTime.now().toIso8601String();
      final updatedAt = DateTime.now().toIso8601String();

      final localSale = {
        'id': saleId,
        'businessId': businessId,
        'customerId': customerId,
        'totalAmount': (saleData['totalAmount'] ?? saleData['total'] ?? 0).toString(),
        'discountAmount': (saleData['discountAmount'] ?? saleData['discount'] ?? 0).toString(),
        'taxAmount': (saleData['taxAmount'] ?? saleData['tax'] ?? 0).toString(),
        'finalAmount': (saleData['finalAmount'] ?? saleData['total'] ?? 0).toString(),
        'paymentMethod': paymentMethod,
        'status': status,
        'notes': notes,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'syncStatus': 'pending',
      };

      await _dbHelper.insert('sales', localSale);

      if (saleData['items'] is List) {
        final items = List.from(saleData['items'] as List);
        for (var index = 0; index < items.length; index++) {
          final rawItem = items[index];
          if (rawItem is! Map) continue;
          final itemMap = Map<String, dynamic>.from(rawItem);
          final itemId = itemMap['id']?.toString() ??
              'SI-$saleId-$index-${DateTime.now().microsecondsSinceEpoch}';
          final quantity = (itemMap['quantity'] is num)
              ? (itemMap['quantity'] as num).toDouble()
              : double.tryParse(itemMap['quantity']?.toString() ?? '0') ?? 0.0;
          final unitPrice = (itemMap['unitPrice'] is num)
              ? (itemMap['unitPrice'] as num).toDouble()
              : double.tryParse(itemMap['unitPrice']?.toString() ?? '0') ?? 0.0;
          final total = (itemMap['total'] is num)
              ? (itemMap['total'] as num).toDouble()
              : double.tryParse(itemMap['total']?.toString() ?? '0') ?? (unitPrice * quantity);

          await _dbHelper.insert('sale_items', {
            'id': itemId,
            'saleId': saleId,
            'productId': itemMap['productId']?.toString() ?? '',
            'productName': itemMap['productName']?.toString() ?? itemMap['name']?.toString() ?? '',
            'quantity': quantity,
            'unitPrice': unitPrice,
            'discount': (itemMap['discount'] ?? 0).toString(),
            'total': total,
          });
        }
      }

      return saleId;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingOfflineSales() async {
    try {
      final pending = await _dbHelper.query('sales',
          where: 'syncStatus = ?', whereArgs: ['pending']);
      final failed = await _dbHelper.query('sales',
          where: 'syncStatus = ?', whereArgs: ['failed']);
      final errored = await _dbHelper.query('sales',
          where: 'syncStatus = ?', whereArgs: ['error']);
      return [...pending, ...failed, ...errored];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> markSaleAsSynced(String saleId) async {
    try {
      await _dbHelper.update('sales', {'syncStatus': 'synced'},
          where: 'id = ?', whereArgs: [saleId]);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteOfflineSale(String saleId) async {
    try {
      await _dbHelper.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    } catch (e) {
      rethrow;
    }
  }
}
