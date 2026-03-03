import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/utils/datetime_utils.dart';
import '../data/repositories/procurement_repository.dart';
import '../data/repositories/sales_repository_impl.dart';

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

  final SalesRepositoryImpl _salesRepo;
  final ProcurementRepository _procRepo;

  ProductHistoryProvider({SalesRepositoryImpl? salesRepo, ProcurementRepository? procRepo})
      : start = DateTime.now().subtract(const Duration(days: 30)),
        end = DateTime.now(),
        _salesRepo = salesRepo ?? SalesRepositoryImpl(firestore: FirebaseFirestore.instance),
        _procRepo = procRepo ?? ProcurementRepository(firestore: FirebaseFirestore.instance);

  void setRange(DateTime s, DateTime e) {
    start = s;
    end = e;
    // Clear cache when range changes
    _cachedStart = null;
    _cachedEnd = null;
    notifyListeners();
  }

  Stream<QuerySnapshot> procurementsStream({required String businessId, required String productId}) {
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
      // Fetch sales with optimized query
      final salesList = await _salesRepo.fetchSales(
        businessId: businessId,
        start: start,
        end: end,
      );

      // Filter to only matched products - do minimal processing
      final matched = <Map<String, dynamic>>[];
      
      for (final s in salesList) {
        try {
          final items = (s['items'] as List<dynamic>?) ?? [];
          
          for (final it in items) {
            if (it is! Map) continue;
            
            // Match product ID
            final pid = (it['productId'] ?? it['id'] ?? it['product_id'] ?? it['productIdStr'] ?? '').toString();
            if (pid != productId.toString()) continue;

            // Extract quantity
            double qty = _parseQuantity(it['quantity'] ?? it['qty'] ?? it['quantitySold'] ?? it['qtySold'] ?? it['soldQty']);

            // Extract price
            double price = _parsePrice(it['price'] ?? it['sellingPrice'] ?? it['amount'] ?? it['unitPrice']);

            // Extract sale ID
            final saleId = (s['id'] ?? s['saleId'] ?? s['transactionId'] ?? s['sale_id'] ?? '')?.toString() ?? '';

            // Get created date - already filtered by Firebase query
            final createdRaw = s['createdAt'] ?? s['created_at'] ?? s['timestamp'];
            final created = parseTimestamp(createdRaw);

            matched.add({
              'saleId': saleId,
              'date': created,
              'quantity': qty,
              'price': price,
              'total': (qty * price),
              'paymentMethod': s['paymentMethod'] ?? s['method'] ?? s['payment_method'] ?? '',
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
