import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../providers/drink_provider.dart';

DateTime _parseDrinkRepoDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}

/// Supabase/Postgres-backed implementation of DrinkRepository.
/// Replaces the Firestore version. Drinks are just inventory items (the
/// `/api/inventory` routes, already used by every migrated vertical) with
/// bar-only fields (bottlesPerCarton/emoji/imageUrl, bottle/carton stock
/// breakdown) folded into inventory's generic `metadata` JSONB column.
/// Bar tables, draft orders and invoices/tabs are genuinely bar-only and
/// live under `/api/drink`.
class DrinkRepositoryImpl implements DrinkRepository {
  final String businessId;
  final Dio _http;
  final SupabaseClient _supabase;

  DrinkRepositoryImpl({required this.businessId, Dio? http, SupabaseClient? supabase})
      : _http = http ??
            Dio(BaseOptions(
              baseUrl: '${SupabaseConfig.url}/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            )),
        _supabase = supabase ?? Supabase.instance.client;

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

  static const _pollInterval = Duration(seconds: 15);

  // ---------- Drinks / inventory ----------

  DrinkItem _drinkFromRow(Map<String, dynamic> row) {
    final metadata = (row['metadata'] is Map) ? Map<String, dynamic>.from(row['metadata'] as Map) : <String, dynamic>{};
    return DrinkItem(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? '').toString(),
      pricePerBottle: double.tryParse('${row['unit_price'] ?? 0}') ?? 0.0,
      bottlesPerCarton: 1,
      emoji: (metadata['emoji'] as String?) ?? '🥤',
      imageUrl: metadata['imageUrl'] as String?,
      category: (row['category'] as String?) ?? 'Drinks',
      description: (row['description'] as String?) ?? '',
    );
  }

  @override
  Future<void> saveDrink(DrinkItem drink) async {
    try {
      await _http.post(
        '/inventory/$businessId',
        data: {
          'id': drink.id,
          'name': drink.name,
          'unit_price': drink.pricePerBottle,
          'cost_price': 0.0,
          'quantity': 0,
          'category': drink.category,
          'description': drink.description,
          'unit': 'bottle',
          'min_stock_level': 10,
          'metadata': {
            'emoji': drink.emoji,
            'imageUrl': drink.imageUrl,
          },
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to save drink: ${_extractError(e)}');
    }
  }

  @override
  Future<List<DrinkItem>> fetchDrinks() async {
    try {
      final rows = await _fetchAllInventoryPages();
      return rows.map((r) => _drinkFromRow(Map<String, dynamic>.from(r as Map))).toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch drinks: ${_extractError(e)}');
    }
  }

  // The backend paginates /inventory (default 50/page, 100 max), so a
  // single request silently truncates any business with a larger catalog -
  // page through every result rather than only ever seeing page 1.
  Future<List<dynamic>> _fetchAllInventoryPages() async {
    final first = await _http.get(
      '/inventory/$businessId',
      queryParameters: {'limit': 100, 'page': 1},
      options: Options(headers: _headers),
    );
    final items = <dynamic>[...(first.data['data'] as List? ?? [])];
    final totalPages = first.data['pagination']?['totalPages'] as int? ?? 1;
    if (totalPages > 1) {
      // Batched, not one unbounded Future.wait - a large catalog blasting
      // dozens of simultaneous requests can exhaust the backend's DB
      // connection pool and stall unrelated requests app-wide.
      const batchSize = 5;
      for (var batchStart = 2; batchStart <= totalPages; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize - 1).clamp(batchStart, totalPages);
        final batch = await Future.wait([
          for (var page = batchStart; page <= batchEnd; page++)
            _http.get(
              '/inventory/$businessId',
              queryParameters: {'limit': 100, 'page': page},
              options: Options(headers: _headers),
            ),
        ]);
        for (final response in batch) {
          items.addAll(response.data['data'] as List? ?? []);
        }
      }
    }
    return items;
  }

  @override
  Stream<List<DrinkItem>> streamDrinks() async* {
    while (true) {
      try {
        yield await fetchDrinks();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  // ---------- Inventory (bottle/carton stock) ----------

  StockItem _stockFromRow(Map<String, dynamic> row) {
    final metadata = (row['metadata'] is Map) ? Map<String, dynamic>.from(row['metadata'] as Map) : <String, dynamic>{};
    final bottles = (metadata['bottles'] as num?)?.toInt() ?? (row['quantity'] as num?)?.toInt() ?? 0;
    final cartons = (metadata['cartons'] as num?)?.toInt() ?? 0;
    return StockItem(drinkId: (row['id'] ?? '').toString(), bottles: bottles, cartons: cartons);
  }

  @override
  Future<List<StockItem>> fetchInventory() async {
    try {
      final rows = await _fetchAllInventoryPages();
      return rows.map((r) => _stockFromRow(Map<String, dynamic>.from(r as Map))).toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch inventory: ${_extractError(e)}');
    }
  }

  @override
  Stream<List<StockItem>> streamInventory() async* {
    while (true) {
      try {
        yield await fetchInventory();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  @override
  Future<void> updateStock(String drinkId, StockItem stock) async {
    try {
      await _http.put(
        '/inventory/$businessId/$drinkId',
        data: {
          'quantity': stock.bottles,
          'metadata': {'bottles': stock.bottles, 'cartons': stock.cartons},
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update stock: ${_extractError(e)}');
    }
  }

  @override
  Future<void> deleteDrink(String drinkId) async {
    try {
      await _http.delete('/inventory/$businessId/$drinkId', options: Options(headers: _headers));
    } on DioException catch (e) {
      throw Exception('Failed to delete drink: ${_extractError(e)}');
    }
  }

  @override
  Future<void> deleteInventory(String drinkId) async {
    try {
      await _http.delete('/inventory/$businessId/$drinkId', options: Options(headers: _headers));
    } on DioException catch (e) {
      throw Exception('Failed to delete inventory: ${_extractError(e)}');
    }
  }

  // ---------- Orders (draft/pre-payment) ----------

  Order _orderFromRow(Map<String, dynamic> row) {
    final lines = (row['lines'] as List<dynamic>? ?? const [])
        .map((item) => OrderLine.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return Order(
      id: (row['id'] ?? '').toString(),
      status: (row['status'] ?? 'pending').toString(),
      createdAt: _parseDrinkRepoDate(row['created_at']),
      lines: lines,
    );
  }

  @override
  Future<void> saveOrder(Map<String, dynamic> data) async {
    try {
      await _http.post(
        '/drink/$businessId/orders',
        data: {
          'id': data['id'],
          'status': data['status'],
          'lines': data['lines'],
          'total': data['total'],
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to save order: ${_extractError(e)}');
    }
  }

  @override
  Future<List<Order>> fetchOrders() async {
    try {
      final response = await _http.get('/drink/$businessId/orders', options: Options(headers: _headers));
      final rows = (response.data['data'] as List?) ?? [];
      return rows.map((r) => _orderFromRow(Map<String, dynamic>.from(r as Map))).toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch orders: ${_extractError(e)}');
    }
  }

  @override
  Stream<List<Order>> streamOrders() async* {
    while (true) {
      try {
        yield await fetchOrders();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  // ---------- Invoices (open tabs/tables, converted to a sale on payment) ----------

  BarInvoice _invoiceFromRow(Map<String, dynamic> row) {
    return BarInvoice.fromJson({
      'id': row['id'],
      'businessId': row['business_id'],
      'invoiceNumber': row['invoice_number'],
      'invoiceType': row['invoice_type'],
      'status': row['status'],
      'customerId': row['customer_id'],
      'customerName': row['customer_name'],
      'customerPhone': row['customer_phone'],
      'customerEmail': row['customer_email'],
      'tableLabel': row['table_label'],
      'notes': row['notes'],
      'lines': row['lines'],
      'subtotal': row['subtotal'],
      'tax': row['tax'],
      'discount': row['discount'],
      'total': row['total'],
      'createdAt': row['created_at'],
      'convertedAt': row['converted_at'],
      'linkedSaleId': row['linked_sale_id'],
      'paymentMethod': row['payment_method'],
      'workerId': row['worker_id'],
      'workerName': row['worker_name'],
      'storeId': row['store_id'],
    });
  }

  @override
  Future<void> saveInvoice(Map<String, dynamic> data) async {
    try {
      await _http.post(
        '/drink/$businessId/invoices',
        data: {
          'id': data['id'],
          'invoice_number': data['invoiceNumber'],
          'invoice_type': data['invoiceType'],
          'status': data['status'],
          'customer_id': data['customerId'],
          'customer_name': data['customerName'],
          'customer_phone': data['customerPhone'],
          'customer_email': data['customerEmail'],
          'table_label': data['tableLabel'],
          'notes': data['notes'],
          'lines': data['lines'],
          'subtotal': data['subtotal'],
          'tax': data['tax'],
          'discount': data['discount'],
          'total': data['total'],
          'converted_at': data['convertedAt'],
          'linked_sale_id': data['linkedSaleId'],
          'payment_method': data['paymentMethod'],
          'worker_id': data['workerId'],
          'worker_name': data['workerName'],
          'store_id': data['storeId'],
        },
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to save invoice: ${_extractError(e)}');
    }
  }

  @override
  Future<List<BarInvoice>> fetchInvoices() async {
    try {
      final response = await _http.get('/drink/$businessId/invoices', options: Options(headers: _headers));
      final rows = (response.data['data'] as List?) ?? [];
      final invoices = rows.map((r) => _invoiceFromRow(Map<String, dynamic>.from(r as Map))).toList();
      invoices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invoices;
    } on DioException catch (e) {
      throw Exception('Failed to fetch invoices: ${_extractError(e)}');
    }
  }

  @override
  Stream<List<BarInvoice>> streamInvoices() async* {
    while (true) {
      try {
        yield await fetchInvoices();
      } catch (_) {
        // Swallow transient errors between polls so the stream stays alive.
      }
      await Future.delayed(_pollInterval);
    }
  }

  // ---------- Bar tables ----------

  @override
  Future<List<String>> fetchBarTables() async {
    try {
      final response = await _http.get('/drink/$businessId/bar-tables', options: Options(headers: _headers));
      final rows = (response.data['data'] as List?) ?? [];
      return rows.map((r) => (r['label'] ?? '').toString()).where((l) => l.isNotEmpty).toList();
    } on DioException catch (e) {
      throw Exception('Failed to fetch bar tables: ${_extractError(e)}');
    }
  }

  @override
  Future<void> saveBarTable(String label) async {
    try {
      await _http.post(
        '/drink/$businessId/bar-tables',
        data: {'label': label},
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to save bar table: ${_extractError(e)}');
    }
  }

  @override
  Future<void> deleteBarTable(String label) async {
    try {
      await _http.delete('/drink/$businessId/bar-tables/${Uri.encodeComponent(label)}', options: Options(headers: _headers));
    } on DioException catch (e) {
      throw Exception('Failed to delete bar table: ${_extractError(e)}');
    }
  }

  // ---------- Sales ----------

  @override
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      final items = (saleData['items'] as List<dynamic>? ?? const []).map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return {
          'product_id': item['productId'],
          'product_name': item['productName'],
          'quantity': item['quantity'],
          'unit_price': item['unitPrice'],
          'discount': 0,
          'total': item['total'],
        };
      }).toList();

      final response = await _http.post(
        '/sales/$businessId',
        data: {
          'id': saleData['id'],
          'customer_id': saleData['customerId'],
          'store_id': saleData['storeId'],
          'worker_id': saleData['workerId'],
          'worker_name': saleData['workerName'],
          'total_amount': saleData['subtotal'] ?? saleData['total'],
          'discount_amount': saleData['discount'] ?? 0,
          'tax_amount': saleData['tax'] ?? 0,
          'final_amount': saleData['total'] ?? saleData['totalAmount'] ?? saleData['finalAmount'],
          'payment_method': saleData['paymentMethod'],
          'status': saleData['status'] ?? 'completed',
          'notes': saleData['notes'],
          'created_by': saleData['workerId'],
          'sale_type': 'bar',
          'items': items,
        },
        options: Options(headers: _headers),
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      throw Exception('Failed to create sale: ${_extractError(e)}');
    }
  }

  @override
  Future<double> getSalesTotal({String? period, DateTime? start, DateTime? end}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (period != null) queryParams['period'] = period;
      if (start != null) queryParams['startDate'] = start.toIso8601String();
      if (end != null) queryParams['endDate'] = end.toIso8601String();
      if (period == null && start == null && end == null) {
        // Summary defaults to "this month" server-side; pass an explicit
        // wide range to approximate an all-time total.
        queryParams['startDate'] = DateTime(2000, 1, 1).toIso8601String();
        queryParams['endDate'] = DateTime.now().toIso8601String();
      }
      final response = await _http.get(
        '/sales/$businessId/summary',
        queryParameters: queryParams,
        options: Options(headers: _headers),
      );
      return double.tryParse('${response.data['total_revenue'] ?? 0}') ?? 0.0;
    } on DioException catch (e) {
      throw Exception('Failed to fetch sales total: ${_extractError(e)}');
    }
  }

  @override
  Future<void> mergeCustomerMetadata(String customerId, Map<String, dynamic> metadata) async {
    try {
      await _http.patch(
        '/customers/$businessId/$customerId/metadata',
        data: {'metadata': metadata},
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      throw Exception('Failed to update customer metadata: ${_extractError(e)}');
    }
  }

  // ---------- Shifts (no live UI caller; kept as a harmless no-op to
  // satisfy the DrinkRepository interface) ----------

  @override
  Future<void> startShift(Shift shift) async {}
}
