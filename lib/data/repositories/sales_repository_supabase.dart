import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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
  Future<Map<String, dynamic>?> deleteSaleForBusiness(String businessId, String saleId,
      {String? reason}) async {
    try {
      final response = await _http.delete(
        '/sales/$businessId/$saleId',
        data: reason != null ? {'reason': reason} : null,
        options: Options(headers: _headers),
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } on DioException catch (e) {
      throw Exception('Failed to delete sale: ${_extractError(e)}');
    }
  }

  @override
  Future<List<dynamic>> getSales(String businessId,
      {Map<String, dynamic>? filters}) async {
    // Only an unfiltered fetch reflects the *complete* history - caching a
    // filtered/date-ranged result under the same businessId key would
    // silently overwrite the full-history cache with a partial one, so
    // those calls bypass the cache read/write below (same precaution
    // InventoryRepositorySupabase.getInventory takes).
    final isFullFetch = filters == null || filters.isEmpty;

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
        if (filters.containsKey('limit') && filters['limit'] != null) {
          queryParams['limit'] = filters['limit'];
        }
      }

      final items = await _fetchAllSalesPages(businessId, queryParams);

      if (isFullFetch) {
        unawaited(_cacheSales(businessId, items).catchError(
          (e) => debugPrint('[SalesRepositorySupabase] Cache write failed: $e'),
        ));
      }

      return items;
    } on DioException catch (e) {
      if (isFullFetch) {
        final cached = await _getCachedSales(businessId);
        if (cached.isNotEmpty) {
          debugPrint(
              '[SalesRepositorySupabase] Network fetch failed, serving ${cached.length} cached sale(s): ${_extractError(e)}');
          return cached;
        }
      }
      throw Exception('Failed to fetch sales: ${_extractError(e)}');
    }
  }

  // ---------- Local cache (SQLite via DatabaseHelper) ----------
  // Reuses the same local `sales`/`sale_items` tables offline-queued sales
  // are written to (syncStatus distinguishes a locally-queued sale awaiting
  // upload from a server-fetched one cached for offline viewing), so Sales
  // History has something to show ("at least the cache") when the network
  // fetch fails instead of going blank.

  Future<void> _cacheSales(String businessId, List<dynamic> items) async {
    // Only overwrite this business's *synced* cache rows - a pending/failed
    // local sale still awaiting upload must not be wiped out by a server
    // fetch that doesn't know about it yet.
    await _dbHelper.delete('sales',
        where: 'businessId = ? AND syncStatus = ?',
        whereArgs: [businessId, 'synced']);
    for (final raw in items) {
      final row = Map<String, dynamic>.from(raw as Map);
      final saleId = row['id']?.toString() ?? '';
      if (saleId.isEmpty) continue;
      await _dbHelper.insert('sales', {
        'id': saleId,
        'businessId': businessId,
        'customerId': row['customer_id'],
        'totalAmount': (row['total_amount'] as num?)?.toDouble() ?? 0.0,
        'discountAmount': (row['discount_amount'] as num?)?.toDouble() ?? 0.0,
        'taxAmount': (row['tax_amount'] as num?)?.toDouble() ?? 0.0,
        'finalAmount': (row['final_amount'] as num?)?.toDouble() ??
            (row['total_amount'] as num?)?.toDouble() ??
            0.0,
        'paymentMethod': row['payment_method'] ?? '',
        if (row['payment_breakdown'] != null)
          'paymentBreakdown': jsonEncode(row['payment_breakdown']),
        'status': row['status'] ?? 'completed',
        'notes': row['notes'],
        'createdBy': row['created_by'] ?? '',
        'createdAt': row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updatedAt': row['updated_at']?.toString(),
        'syncStatus': 'synced',
        'storeId': row['store_id'],
        'workerId': row['worker_id'],
        'workerName': row['worker_name'],
        'saleType': row['sale_type'],
      });

      final items0 = row['items'];
      if (items0 is List) {
        for (final rawItem in items0) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem);
          final itemId = item['id']?.toString() ??
              '$saleId-${item['product_id'] ?? item['productId'] ?? ''}';
          await _dbHelper.insert('sale_items', {
            'id': itemId,
            'saleId': saleId,
            'productId': item['product_id'] ?? item['productId'] ?? '',
            'productName': item['product_name'] ?? item['productName'] ?? '',
            'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
            'unitPrice': (item['unit_price'] as num?)?.toDouble() ??
                (item['unitPrice'] as num?)?.toDouble() ??
                0.0,
            'discount': (item['discount'] as num?)?.toDouble() ?? 0.0,
            'total': (item['total'] as num?)?.toDouble() ?? 0.0,
            'pricingMode': item['pricing_mode'] ?? item['pricingMode'],
            'inventoryUnit': item['inventory_unit'] ?? item['inventoryUnit'],
            'saleUnit': item['sale_unit'] ?? item['saleUnit'],
            'saleUnitMultiplier':
                (item['sale_unit_multiplier'] as num?)?.toDouble() ??
                    (item['saleUnitMultiplier'] as num?)?.toDouble(),
          });
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getCachedSales(String businessId) async {
    final rows = await _dbHelper.query('sales',
        where: 'businessId = ? AND syncStatus = ?',
        whereArgs: [businessId, 'synced'],
        orderBy: 'createdAt DESC');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final saleId = row['id']?.toString() ?? '';
      final itemRows = saleId.isEmpty
          ? <Map<String, dynamic>>[]
          : await _dbHelper.query('sale_items',
              where: 'saleId = ?', whereArgs: [saleId]);
      result.add({
        ...Map<String, dynamic>.from(row),
        'items': itemRows.map((i) => Map<String, dynamic>.from(i)).toList(),
      });
    }
    return result;
  }

  // The backend paginates /sales (default 50/page, 500 max regardless of
  // what `limit` is requested), so a single request silently truncates any
  // business/date-range with a larger result set - page through everything
  // rather than only ever seeing the first rows. Using the server's max page
  // size cuts round-trips ~5x for a high-volume business (e.g. ~5 requests
  // instead of ~24 for 2,300+ sales in a report's date range).
  Future<List<dynamic>> _fetchAllSalesPages(
      String businessId, Map<String, dynamic> queryParams) async {
    final requestedLimit = (queryParams['limit'] as num?)?.toInt();
    final pageLimit = requestedLimit != null && requestedLimit > 0
        ? requestedLimit.clamp(1, 500)
        : 500;
    final params = {...queryParams, 'limit': pageLimit};
    // A large-volume business (2,000+ sales in a report's date range) can
    // legitimately take longer per page than the client's default 15s
    // receiveTimeout under real backend load, which surfaced as the Sales
    // Report screen hard-failing with a timeout exception instead of just
    // taking a bit longer to load. This path is a background report fetch,
    // not a user-blocking action like checkout, so it can afford to wait.
    final reportPageTimeout = Options(receiveTimeout: const Duration(seconds: 45));
    final first = await _http.get(
      '/sales/$businessId',
      queryParameters: {...params, 'page': 1},
      options: reportPageTimeout.copyWith(headers: _headers),
    );
    final items = <dynamic>[...(first.data['data'] as List? ?? [])];
    if (requestedLimit != null && requestedLimit > 0 && items.length >= requestedLimit) {
      return items.take(requestedLimit).toList();
    }
    final totalPages = first.data['pagination']?['totalPages'] as int? ?? 1;
    if (totalPages > 1) {
      // Firing every remaining page at once (unbounded Future.wait) is fine
      // for a small catalog but not for sales history - a high-volume
      // business can have hundreds of pages, and blasting them all
      // concurrently exhausts the backend's DB connection pool (default 20),
      // causing unrelated requests across the whole app to time out. Batch
      // it instead.
      const batchSize = 5;
      for (var batchStart = 2; batchStart <= totalPages; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize - 1).clamp(batchStart, totalPages);
        final batch = await Future.wait([
          for (var page = batchStart; page <= batchEnd; page++)
            _http.get(
              '/sales/$businessId',
              queryParameters: {...params, 'page': page},
              options: reportPageTimeout.copyWith(headers: _headers),
            ),
        ]);
        for (final response in batch) {
          items.addAll(response.data['data'] as List? ?? []);
        }
        if (requestedLimit != null && requestedLimit > 0 && items.length >= requestedLimit) {
          return items.take(requestedLimit).toList();
        }
      }
    }
    return items;
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
    int? limit,
  }) async {
    if (businessId == null || businessId.isEmpty) {
      throw Exception('Business ID is required to fetch sales');
    }

    try {
      final queryParams = <String, dynamic>{};
      if (storeId != null && storeId.isNotEmpty) {
        queryParams['storeId'] = storeId;
      }
      if (start != null) {
        queryParams['startDate'] = start.toIso8601String();
      }
      if (end != null) {
        queryParams['endDate'] = end.toIso8601String();
      }
      if (limit != null && limit > 0) {
        queryParams['limit'] = limit;
      }

      final data = await _fetchAllSalesPages(businessId, queryParams);
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
    dynamic paymentBreakdown;
    final rawPaymentBreakdown =
        saleData['paymentBreakdown'] ?? saleData['payment_breakdown'];
    if (rawPaymentBreakdown is String &&
        rawPaymentBreakdown.trim().isNotEmpty) {
      try {
        paymentBreakdown = jsonDecode(rawPaymentBreakdown);
      } catch (_) {
        paymentBreakdown = null;
      }
    } else if (rawPaymentBreakdown is List) {
      paymentBreakdown = rawPaymentBreakdown;
    }

    if (saleData['items'] is List) {
      for (final raw in saleData['items'] as List) {
        if (raw is Map) {
          // Local sale_items rows are stored in camelCase, but the
          // backend's insert route reads snake_case fields off each item
          // (item.product_id, item.unit_price, ...) - sending the raw
          // camelCase map through left every field it read as undefined,
          // so items still failed to insert correctly server-side even
          // once they were attached to the payload at all.
          final item = Map<String, dynamic>.from(raw);
          items.add({
            'product_id': item['productId'] ?? item['product_id'],
            'product_name': item['productName'] ?? item['product_name'],
            'quantity': item['quantity'],
            'unit_price': item['unitPrice'] ?? item['unit_price'],
            'discount': item['discount'] ?? 0,
            'total': item['total'],
            'pricing_mode': item['pricingMode'] ?? item['pricing_mode'],
            'inventory_unit': item['inventoryUnit'] ?? item['inventory_unit'],
            'sale_unit': item['saleUnit'] ?? item['sale_unit'],
            'sale_unit_multiplier': item['saleUnitMultiplier'] ??
                item['sale_unit_multiplier'] ??
                1,
          });
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
      if (paymentBreakdown != null) 'payment_breakdown': paymentBreakdown,
      'status': saleData['status']?.toString() ?? 'completed',
      'notes': saleData['notes']?.toString(),
      'created_by': saleData['createdBy']?.toString() ?? '',
      'sale_type': saleData['saleType']?.toString() ?? 'retail',
      // Without this, the backend defaults created_at to NOW() on insert,
      // so a sale rung up offline and synced the next day landed in the
      // sync day's sales report instead of the day it actually happened.
      'created_at': saleData['createdAt']?.toString(),
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
        if (saleData['paymentBreakdown'] != null ||
            saleData['payment_breakdown'] != null)
          'paymentBreakdown': saleData['paymentBreakdown'] is String
              ? saleData['paymentBreakdown']
              : jsonEncode(
                  saleData['paymentBreakdown'] ??
                      saleData['payment_breakdown'],
                ),
        'saleType': saleData['saleType']?.toString() ??
            saleData['sale_type']?.toString() ??
            'retail',
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
      final sales = [...pending, ...failed, ...errored];

      // This query only ever touched the `sales` table - the returned rows
      // never carried their line items, so every offline sale synced with
      // `items: []` regardless of what was actually rung up. That silently
      // dropped the sale's line items server-side (no sale_items rows) AND
      // skipped the backend's inventory-deduction loop, which only runs
      // when items is non-empty. Attach each sale's real sale_items here so
      // the payload built from this data actually reflects what was sold.
      final result = <Map<String, dynamic>>[];
      for (final sale in sales) {
        final saleId = sale['id']?.toString() ?? '';
        final mutable = Map<String, dynamic>.from(sale);
        if (saleId.isNotEmpty) {
          final items = await _dbHelper.query('sale_items',
              where: 'saleId = ?', whereArgs: [saleId]);
          mutable['items'] = items;
        }
        result.add(mutable);
      }
      return result;
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
