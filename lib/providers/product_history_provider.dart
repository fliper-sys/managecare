import 'package:flutter/material.dart';
import '../core/utils/datetime_utils.dart';
import '../data/repositories/procurement_repository.dart';
import '../services/managecare_api_client.dart';

class ProductHistoryProvider extends ChangeNotifier {
  DateTime start;
  DateTime end;
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> sales = [];

  // Caching for performance
  String? _cachedBusinessId;
  String? _cachedProductId;
  DateTime? _cachedStart;
  DateTime? _cachedEnd;

  final ManagecareApiClient _api;
  final ProcurementRepository _procRepo;

  ProductHistoryProvider({ManagecareApiClient? api, ProcurementRepository? procRepo})
      : start = DateTime.now().subtract(const Duration(days: 30)),
        end = DateTime.now(),
        _api = api ?? ManagecareApiClient.instance,
        _procRepo = procRepo ?? ProcurementRepository();

  void setRange(DateTime s, DateTime e) {
    start = s;
    end = e;
    // Clear cache when range changes
    _cachedStart = null;
    _cachedEnd = null;
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> procurementsStream({required String businessId, required String productId}) {
    return _procRepo.productProcurementsStream(businessId: businessId, productId: productId);
  }

  /// Check if cached data is valid
  bool _isCacheValid(String businessId, String productId) {
    return _cachedBusinessId == businessId &&
        _cachedProductId == productId &&
        _cachedStart == start &&
        _cachedEnd == end;
  }

  Future<void> loadSales({required String? businessId, required String productId}) async {
    // Return cached results if available
    if (_isCacheValid(businessId ?? '', productId)) {
      return;
    }

    loading = true;
    error = null;
    sales = [];
    notifyListeners();

    if (businessId == null || businessId.isEmpty) {
      error = 'No business selected';
      loading = false;
      notifyListeners();
      return;
    }

    try {
      final normalizedProductId = productId.toLowerCase();
      final salesList = <Map<String, dynamic>>[];

      try {
        final response = await _api.get('/api/sales/$businessId', query: {'limit': 1000});
        final rows = ((response['data'] as List?) ?? []).cast<Map<String, dynamic>>();
        salesList.addAll(rows);
      } catch (e) {
        debugPrint('ProductHistoryProvider sales load failed: $e');
      }

      // Filter to only matched products - do minimal processing
      final matched = <Map<String, dynamic>>[];

      for (final s in salesList) {
        try {
          final items = (s['items'] as List<dynamic>?) ?? [];

          for (final it in items) {
            if (it is! Map) continue;

            // Match product ID (backend returns snake_case item fields)
            final pid = (it['product_id'] ?? it['productId'] ?? it['id'] ?? '').toString();
            final pname = (it['product_name'] ?? it['productName'] ?? it['name'] ?? '').toString();
            final normalizedPid = pid.toLowerCase();
            final normalizedName = pname.toLowerCase();
            if (normalizedPid != normalizedProductId &&
                !normalizedPid.contains(normalizedProductId) &&
                !normalizedProductId.contains(normalizedPid) &&
                !normalizedName.contains(normalizedProductId) &&
                !normalizedProductId.contains(normalizedName)) {
              continue;
            }

            // Extract quantity
            double qty = _parseQuantity(it['quantity'] ?? it['qty']);

            // Extract price
            double price = _parsePrice(it['unit_price'] ?? it['unitPrice'] ?? it['price']);

            // Extract sale ID
            final saleId = (s['id'] ?? '').toString();

            // Apply the selected date range locally so the full history can be queried safely
            final createdRaw = s['created_at'] ?? s['createdAt'];
            final created = parseTimestamp(createdRaw);
            if (created.isBefore(start) || created.isAfter(end)) continue;

            matched.add({
              'saleId': saleId,
              'date': created,
              'quantity': qty,
              'price': price,
              'total': (qty * price),
              'paymentMethod': s['payment_method'] ?? s['paymentMethod'] ?? '',
            });
          }
        } catch (e) {
          debugPrint('Error processing sale record: $e');
          // Skip individual records that fail
        }
      }

      // Sort by date (most recent first)
      matched.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      sales = matched;

      // Update cache
      _cachedBusinessId = businessId;
      _cachedProductId = productId;
      _cachedStart = start;
      _cachedEnd = end;

      loading = false;
      notifyListeners();
    } catch (e) {
      error = 'Failed to load sales history: ${e.toString()}';
      debugPrint('ProductHistoryProvider Error: $error');
      loading = false;
      notifyListeners();
    }
  }

  /// Parse quantity with robust error handling
  double _parseQuantity(dynamic rawQty) {
    if (rawQty is num) return rawQty.toDouble();
    if (rawQty == null) return 0.0;

    try {
      final cleaned = rawQty.toString().replaceAll(RegExp(r'[^0-9.\\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Parse price with robust error handling
  double _parsePrice(dynamic rawPrice) {
    if (rawPrice is num) return rawPrice.toDouble();
    if (rawPrice == null) return 0.0;

    try {
      return double.tryParse(rawPrice.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Clear cache manually
  void clearCache() {
    _cachedBusinessId = null;
    _cachedProductId = null;
    _cachedStart = null;
    _cachedEnd = null;
  }
}
