import 'dart:convert';

import '../../../core/utils/datetime_utils.dart';

/// A sale row as the history list shows it, parsed from the loose maps the
/// backend and the offline database return. All the fallbacks of the old
/// history screen are kept, because older sales miss fields.
class SaleSummary {
  SaleSummary({
    required this.raw,
    required this.id,
    required this.title,
    required this.customer,
    required this.itemCount,
    required this.itemsText,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.pendingSync,
  });

  final Map<String, dynamic> raw;
  final String id;
  final String title;
  final String customer;
  final int itemCount;
  final String itemsText;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;
  final bool pendingSync;

  bool get isRefunded => status.toLowerCase() == 'refunded';
  bool get isPartiallyRefunded => status.toLowerCase() == 'partially_refunded';

  /// Matches the search box against reference, customer and product names.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        customer.toLowerCase().contains(q) ||
        itemsText.toLowerCase().contains(q) ||
        id.toLowerCase().contains(q);
  }

  /// [nameForProduct] looks a product name up by id when the item has no name.
  factory SaleSummary.fromMap(
    Map<String, dynamic> sale, {
    required int index,
    String? Function(String productId)? nameForProduct,
  }) {
    final rawId = (sale['id'] ?? '').toString();
    final title = sale['referenceId'] != null
        ? 'Sale #${sale['referenceId']}'
        : rawId.isEmpty
            ? 'SALE-${index + 1}'
            : 'Sale #${rawId.length > 8 ? rawId.substring(rawId.length - 8) : rawId}';
    final items = (sale['items'] as List?) ?? (sale['cartItems'] as List?);
    return SaleSummary(
      raw: sale,
      id: rawId,
      title: title,
      customer: (sale['customer'] ?? sale['customerName'] ?? sale['buyerName'] ?? 'Walk-in Customer').toString(),
      itemCount: items?.length ?? 1,
      itemsText: productNames(sale, nameForProduct: nameForProduct),
      amount: saleAmount(sale),
      paymentMethod: (sale['paymentMethod'] ?? 'Cash').toString(),
      status: (sale['status'] ?? 'completed').toString(),
      createdAt: sale['createdAt'] == null ? null : parseTimestamp(sale['createdAt']),
      pendingSync: sale['pendingSync'] == true,
    );
  }
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// The sale's total, trying each field the old history screen tried, in the
/// same order, and finally summing the line items.
double saleAmount(Map<String, dynamic> sale) {
  final a = _num(sale['totalAmount']) > 0 ? _num(sale['totalAmount']) : _num(sale['finalAmount']);
  if (a > 0) return a;
  final b = _num(sale['total']) > 0 ? _num(sale['total']) : _num(sale['amount']);
  if (b > 0) return b;
  final sub = _num(sale['subtotal']);
  if (sub > 0) return sub;
  final items = sale['items'] as List?;
  if (items == null || items.isEmpty) return 0;
  return items.fold<double>(0, (sum, raw) {
    if (raw is! Map) return sum;
    final total = _num(raw['total']);
    if (total > 0) return sum + total;
    final qty = _num(raw['quantity']);
    if (qty <= 0) return sum;
    final unit = _num(raw['unitPrice']) > 0 ? _num(raw['unitPrice']) : _num(raw['price']);
    return sum + unit * qty;
  });
}

Map<String, dynamic>? _asItem(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      final parsed = json.decode(raw);
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}
  }
  return null;
}

/// "Rice × 2, Palm oil" for the row subtitle.
String productNames(Map<String, dynamic> sale, {String? Function(String productId)? nameForProduct}) {
  final items = sale['items'] as List?;
  if (items == null || items.isEmpty) return 'No items';
  final out = <String>[];
  for (final raw in items) {
    final item = _asItem(raw);
    if (item == null) {
      out.add(raw?.toString() ?? 'Unknown Item');
      continue;
    }
    String? name;
    for (final k in const ['productName', 'product_name', 'name']) {
      final v = item[k];
      if (v is String && v.isNotEmpty) {
        name = v;
        break;
      }
    }
    if (name == null && item['product'] != null) {
      final p = item['product'];
      if (p is Map && p['name'] is String) {
        name = p['name'] as String;
      } else if (p is String) {
        try {
          final parsed = json.decode(p);
          if (parsed is Map && parsed['name'] != null) name = parsed['name'].toString();
        } catch (_) {}
      }
    }
    if (name == null || name.isEmpty) {
      final pid = item['productId'] ?? item['product_id'];
      if (pid != null) name = nameForProduct?.call(pid.toString());
    }
    final qRaw = item['quantity'] ?? item['qty'] ?? item['count'] ?? item['q'] ?? 1;
    final qty = qRaw is num ? qRaw.toInt() : int.tryParse(qRaw?.toString() ?? '') ?? 1;
    final label = name ?? 'Unknown Product';
    out.add(qty > 1 ? '$label × $qty' : label);
  }
  return out.isEmpty ? 'No items' : out.join(', ');
}

/// "5m ago", "2h ago", "3d ago", then the date.
String relativeTime(DateTime? at, {DateTime? now}) {
  if (at == null) return 'Just now';
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${at.day}/${at.month}/${at.year}';
}
