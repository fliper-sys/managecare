import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    // Only an unfiltered, whole-business fetch reflects the *complete*
    // catalog - caching a filtered/store-scoped result under the same
    // businessId key would silently overwrite the full-catalog cache with a
    // partial one, so those calls bypass the cache read/write below and go
    // straight to the network like before.
    final isFullFetch = (filters == null || filters.isEmpty) &&
        (storeId == null || storeId.isEmpty);

    try {
      final queryParams = <String, dynamic>{};
      if (filters != null) {
        if (filters.containsKey('category')) queryParams['category'] = filters['category'];
        if (filters.containsKey('search')) queryParams['search'] = filters['search'];
        if (filters.containsKey('lowStock')) queryParams['lowStock'] = filters['lowStock'] == true ? 'true' : 'false';
        if (filters.containsKey('isActive')) queryParams['isActive'] = filters['isActive'] == true ? 'true' : 'false';
      }
      if (storeId != null && storeId.isNotEmpty) queryParams['storeId'] = storeId;
      // The backend paginates this endpoint (default 50/page, 100 max) so a
      // single request silently truncates any business with a larger catalog
      // - callers throughout the app (loadProducts, this screen's list, etc.)
      // all expect the full inventory back, so page through every result
      // here rather than pushing that concern onto every call site.
      queryParams['limit'] = 100;
      final first = await _http.get(
        '/inventory/$businessId',
        queryParameters: {...queryParams, 'page': 1},
        options: Options(headers: _headers),
      );
      final items = <dynamic>[...(first.data['data'] as List? ?? [])];
      final totalPages = first.data['pagination']?['totalPages'] as int? ?? 1;
      if (totalPages > 1) {
        // Offset pagination is stateless, so the remaining pages can be
        // fetched concurrently instead of round-tripping one at a time -
        // matters for the businesses with 1000+ item catalogs. Batched
        // (not one unbounded Future.wait) so a very large catalog can't
        // blast dozens of simultaneous requests at the backend's DB
        // connection pool and starve unrelated requests.
        const batchSize = 5;
        for (var batchStart = 2; batchStart <= totalPages; batchStart += batchSize) {
          final batchEnd = (batchStart + batchSize - 1).clamp(batchStart, totalPages);
          final batch = await Future.wait([
            for (var page = batchStart; page <= batchEnd; page++)
              _http.get(
                '/inventory/$businessId',
                queryParameters: {...queryParams, 'page': page},
                options: Options(headers: _headers),
              ),
          ]);
          for (final response in batch) {
            items.addAll(response.data['data'] as List? ?? []);
          }
        }
      }

      // Fields with no dedicated Postgres column (wholesalePrice, saleUnit,
      // emoji, ...) live inside the `metadata` jsonb blob, but Product
      // .fromJson() and everything downstream only ever look at the row's
      // top level - without this, wholesale pricing (and everything else
      // routed through metadata) silently read as absent no matter what
      // was actually saved, on every screen, for every product.
      for (final raw in items) {
        final row = raw as Map;
        final metadata = row['metadata'];
        if (metadata is Map) {
          for (final entry in metadata.entries) {
            row.putIfAbsent(entry.key, () => entry.value);
          }
        }
      }

      // Write-through: persist the full catalog locally (e.g. right after
      // login, when RetailProvider.initialize() calls this) so a later cold
      // start or a network hiccup doesn't force every screen to re-fetch
      // the whole thing over the network again. Fire-and-forget - a caching
      // failure should never block showing the data that was just fetched.
      if (isFullFetch) {
        unawaited(_cacheInventory(businessId, items).catchError(
          (e) => debugPrint('[InventoryRepositorySupabase] Cache write failed: $e'),
        ));
      }

      return items;
    } on DioException catch (e) {
      if (isFullFetch) {
        final cached = await _getCachedInventory(businessId);
        if (cached.isNotEmpty) {
          debugPrint(
              '[InventoryRepositorySupabase] Network fetch failed, serving ${cached.length} cached item(s): ${_extractError(e)}');
          return cached;
        }
      }
      throw Exception('Failed to fetch inventory: ${_extractError(e)}');
    }
  }

  // ---------- Local cache (SQLite/Hive via DatabaseHelper) ----------
  // Mirrors the network row shape into the existing `inventory` table's
  // camelCase columns, so it's read back below as if it came from the API.

  Future<void> _cacheInventory(String businessId, List<dynamic> items) async {
    await _dbHelper.delete('inventory', where: 'businessId = ?', whereArgs: [businessId]);
    for (final raw in items) {
      final row = Map<String, dynamic>.from(raw as Map);
      await _dbHelper.insert('inventory', {
        'id': row['id'],
        'businessId': businessId,
        'name': row['name'] ?? '',
        'sku': row['sku'],
        'barcode': row['barcode'],
        'category': row['category'],
        'description': row['description'],
        'unitPrice': (row['unit_price'] as num?)?.toDouble() ?? 0.0,
        'costPrice': (row['cost_price'] as num?)?.toDouble(),
        'quantity': (row['quantity'] as num?)?.toDouble() ?? 0.0,
        'stock': (row['quantity'] as num?)?.toDouble() ?? 0.0,
        'minStockLevel': (row['min_stock_level'] as num?)?.toDouble() ?? 0.0,
        'unit': row['unit'] ?? 'pcs',
        'expiryDate': row['expiry_date']?.toString(),
        'isActive': row['is_active'] == false ? 0 : 1,
        'createdAt': row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updatedAt': row['updated_at']?.toString(),
        'syncStatus': 'synced',
        'storeId': row['store_id'],
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getCachedInventory(String businessId) async {
    final rows = await _dbHelper.query('inventory', where: 'businessId = ?', whereArgs: [businessId]);
    // Re-shape back to the same snake_case keys the network response uses,
    // so callers (Product.fromJson and friends) can't tell the difference.
    return rows
        .map((row) => {
              'id': row['id'],
              'business_id': row['businessId'],
              'name': row['name'],
              'sku': row['sku'],
              'barcode': row['barcode'],
              'category': row['category'],
              'description': row['description'],
              'unit_price': row['unitPrice'],
              'cost_price': row['costPrice'],
              'quantity': row['quantity'],
              'stock': row['stock'],
              'min_stock_level': row['minStockLevel'],
              'unit': row['unit'],
              'expiry_date': row['expiryDate'],
              'is_active': row['isActive'] == 1,
              'created_at': row['createdAt'],
              'updated_at': row['updatedAt'],
              'store_id': row['storeId'],
            })
        .toList();
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
      final data = await getInventory(businessId, storeId: storeId);
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

  // The custom backend doesn't implement Supabase's Realtime protocol
  // (it's a plain REST API, not real Postgres logical replication over a
  // websocket), so a genuine `.stream()` against it would just hang.
  // Polling is the honest equivalent here.
  static const _pollInterval = Duration(seconds: 15);

  @override
  Stream<List<Map<String, dynamic>>> streamInventory(String businessId, {String? storeId}) async* {
    while (true) {
      try {
        final items = await getInventory(businessId, storeId: storeId);
        yield items.cast<Map<String, dynamic>>();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
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
  Stream<List<Map<String, dynamic>>> streamInventoryHistory(String businessId, String inventoryId) async* {
    while (true) {
      try {
        final response = await _http.get(
          '/inventory/$businessId/$inventoryId/history',
          options: Options(headers: _headers),
        );
        final data = (response.data['data'] as List?) ?? [];
        yield data.cast<Map<String, dynamic>>();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
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

  Future<List<Map<String, dynamic>>> fetchBakeryResupplies({
    required String businessId,
    String? bakerId,
    int limit = 100,
  }) async {
    try {
      final response = await _http.get(
        '/inventory/$businessId/bakery-resupplies',
        queryParameters: {
          'limit': limit,
          if (bakerId != null && bakerId.isNotEmpty) 'baker_id': bakerId,
        },
        options: Options(headers: _headers),
      );
      final rows =
          ((response.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      return rows.map(_bakeryResupplyRowToJson).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load bakery resupplies: ${_extractError(e)}');
    }
  }

  Map<String, dynamic> _bakeryResupplyRowToJson(Map<String, dynamic> row) => {
        'id': row['id'],
        'businessId': row['business_id'],
        'inventoryId': row['inventory_id'],
        'inventoryName': row['inventory_name'],
        'quantity': row['quantity'],
        'unit': row['unit'],
        'bakerId': row['baker_id'],
        'bakerName': row['baker_name'],
        'notes': row['notes'],
        'performedById': row['performed_by_id'],
        'performedByName': row['performed_by_name'],
        'expectedProductionAmount': row['expected_production_amount'],
        'actualProductionAmount': row['actual_production_amount'],
        'productionUnit': row['production_unit'],
        'productionItemName': row['production_item_name'],
        'createdAt': row['created_at'],
      };

  Map<String, dynamic> _buildPayload(Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? data['is_active'];
    return {
      'name': data['name'],
      'sku': data['sku'],
      'barcode': data['barcode'],
      'category': data['category'],
      'description': data['description'],
      // Product.toJson() (the shape RetailProvider.updateProduct/addProduct
      // actually send) uses bare 'price'/'cost', not 'unitPrice'/'costPrice'
      // - without these, every product edit anywhere in the app silently
      // reset both to 0 on save, since neither recognized key was ever present.
      'unit_price': data['unitPrice'] ?? data['unit_price'] ?? data['price'] ?? 0,
      'cost_price': data['costPrice'] ?? data['cost_price'] ?? data['cost'] ?? 0,
      'quantity': data['quantity'] ?? 0,
      'stock': data['stock'],
      'min_stock_level': data['minStockLevel'] ?? data['min_stock_level'] ?? 0,
      'unit': data['unit'] ?? 'pcs',
      'expiry_date': data['expiryDate'] ?? data['expiry_date'],
      'store_id': data['storeId'] ?? data['store_id'],
      // Only included when the caller actually means to touch it - Product
      // .toJson() never sets this key, so defaulting to `true` here meant
      // every ordinary product edit (price change, stock update, etc.)
      // silently reactivated the row, even one that had just been
      // deactivated as a duplicate. The backend's PUT route already treats
      // an absent field as "leave it alone" (`if (is_active !== undefined)`),
      // so omitting the key here is what makes that behavior actually work.
      if (isActive != null) 'is_active': isActive,
      // Fields with no dedicated column (wholesalePrice, saleUnit, emoji,
      // etc.) belong in this catch-all jsonb column - the backend merges it
      // in rather than overwriting (`metadata = metadata || $X::jsonb`), so
      // passing only the keys that changed here never wipes out unrelated
      // metadata some other write already set.
      if (data['metadata'] != null) 'metadata': data['metadata'],
    };
  }
}
