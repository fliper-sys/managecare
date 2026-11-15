import 'package:flutter/foundation.dart';

/// Something that can be sold from a catalogue: product, menu item, drug.
@immutable
class CatalogueItem {
  const CatalogueItem({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.category = '',
    this.unit = '',
  });

  final String id;
  final String name;
  final double price;

  /// Units on hand. Zero means sold out.
  final double stock;
  final String category;
  final String unit;
}

@immutable
class CartLine {
  const CartLine(this.item, this.qty);
  final CatalogueItem item;
  final int qty;
  double get total => item.price * qty;
}

enum PayMethod { cash, transfer, card, credit }

extension PayMethodLabel on PayMethod {
  String get label => switch (this) {
        PayMethod.cash => 'Cash',
        PayMethod.transfer => 'Transfer',
        PayMethod.card => 'Card',
        PayMethod.credit => 'On credit',
      };
}

/// The cart for one business. Create one per tenant (inside `TenantScope`)
/// so a switch cannot carry lines across businesses.
class CartState extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};
  double _discount = 0;

  List<CartLine> get lines => List.unmodifiable(_lines.values);
  int get count => _lines.values.fold(0, (s, l) => s + l.qty);
  bool get isEmpty => _lines.isEmpty;
  double get subtotal => _lines.values.fold(0.0, (s, l) => s + l.total);
  double get discount => _discount;

  /// Never below zero, never above the subtotal.
  double get total => (subtotal - _discount).clamp(0, double.infinity).toDouble();

  int qtyOf(String id) => _lines[id]?.qty ?? 0;

  /// Adds one unit. Returns false when stock is already fully in the cart.
  bool add(CatalogueItem item) {
    final have = qtyOf(item.id);
    if (have + 1 > item.stock) return false;
    _lines[item.id] = CartLine(item, have + 1);
    notifyListeners();
    return true;
  }

  void decrement(String id) {
    final l = _lines[id];
    if (l == null) return;
    if (l.qty <= 1) {
      _lines.remove(id);
    } else {
      _lines[id] = CartLine(l.item, l.qty - 1);
    }
    _fixDiscount();
    notifyListeners();
  }

  void remove(String id) {
    if (_lines.remove(id) != null) {
      _fixDiscount();
      notifyListeners();
    }
  }

  void setDiscount(double amount) {
    _discount = amount.clamp(0, subtotal).toDouble();
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _discount = 0;
    notifyListeners();
  }

  void _fixDiscount() {
    if (_discount > subtotal) _discount = subtotal;
  }
}

/// What the backend returns for a recorded sale; shown on the receipt.
@immutable
class SaleReceipt {
  const SaleReceipt({
    required this.reference,
    required this.when,
    required this.lines,
    required this.total,
    required this.method,
    this.customer,
  });

  final String reference;
  final DateTime when;
  final List<CartLine> lines;
  final double total;
  final PayMethod method;
  final String? customer;
}
