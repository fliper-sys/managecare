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
    this.wholesalePrice,
  });

  final String id;
  final String name;
  final double price;

  /// Units on hand. Zero means sold out.
  final double stock;
  final String category;
  final String unit;

  /// Set when the item is also sold at a wholesale price.
  final double? wholesalePrice;

  bool get hasWholesale => wholesalePrice != null && wholesalePrice! > 0;
}

@immutable
class CartLine {
  const CartLine(this.item, this.qty, {double? unitPrice, this.mode = PriceMode.retail, this.overridden = false})
      : _unit = unitPrice;
  final CatalogueItem item;
  final int qty;
  final PriceMode mode;

  /// True when the cashier typed a price instead of using the list price.
  final bool overridden;
  final double? _unit;
  double get unitPrice => _unit ?? item.price;
  double get total => unitPrice * qty;
}

enum PriceMode { retail, wholesale }

/// One part of a split payment.
@immutable
class PaymentSplit {
  const PaymentSplit(this.method, this.amount);
  final PayMethod method;
  final double amount;
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
  CartState({double taxPercent = 0}) : _taxPercent = taxPercent < 0 ? 0 : taxPercent;

  final Map<String, CartLine> _lines = {};
  final Map<String, double> _overrides = {};
  final Map<String, PriceMode> _lineModes = {};
  PriceMode _mode = PriceMode.retail;
  double _discount = 0;
  double _taxPercent;

  List<CartLine> get lines => List.unmodifiable(_lines.values);
  int get count => _lines.values.fold(0, (s, l) => s + l.qty);
  bool get isEmpty => _lines.isEmpty;
  double get subtotal => _lines.values.fold(0.0, (s, l) => s + l.total);
  double get discount => _discount;
  double get taxPercent => _taxPercent;
  double get taxAmount => subtotal * _taxPercent / 100;
  PriceMode get mode => _mode;

  /// Manual price overrides by item id, for the sale record.
  Map<String, double> get overrides => Map.unmodifiable(_overrides);

  /// Never below zero.
  double get total => (subtotal + taxAmount - _discount).clamp(0, double.infinity).toDouble();

  CartLine? lineOf(String id) => _lines[id];

  int qtyOf(String id) => _lines[id]?.qty ?? 0;

  /// The list price shown in the catalogue for the cart's current mode.
  double listPriceOf(CatalogueItem i) =>
      (_mode == PriceMode.wholesale && i.hasWholesale) ? i.wholesalePrice! : i.price;

  double _priceFor(CatalogueItem i, PriceMode m) {
    final o = _overrides[i.id];
    if (o != null) return o;
    return (m == PriceMode.wholesale && i.hasWholesale) ? i.wholesalePrice! : i.price;
  }

  CartLine _line(CatalogueItem i, int qty) {
    final wanted = _lineModes[i.id] ?? _mode;
    final m = (wanted == PriceMode.wholesale && i.hasWholesale) ? PriceMode.wholesale : PriceMode.retail;
    return CartLine(i, qty, unitPrice: _priceFor(i, m), mode: m, overridden: _overrides.containsKey(i.id));
  }

  /// Adds one unit. Returns false when stock is already fully in the cart.
  bool add(CatalogueItem item) {
    final have = qtyOf(item.id);
    if (have + 1 > item.stock) return false;
    _lines[item.id] = _line(item, have + 1);
    notifyListeners();
    return true;
  }

  void decrement(String id) {
    final l = _lines[id];
    if (l == null) return;
    if (l.qty <= 1) {
      _lines.remove(id);
      _overrides.remove(id);
      _lineModes.remove(id);
    } else {
      _lines[id] = _line(l.item, l.qty - 1);
    }
    _fixDiscount();
    notifyListeners();
  }

  void remove(String id) {
    if (_lines.remove(id) != null) {
      _overrides.remove(id);
      _lineModes.remove(id);
      _fixDiscount();
      notifyListeners();
    }
  }

  /// Switches the whole cart between retail and wholesale list prices. Items
  /// without a wholesale price stay at retail. Manual overrides are kept.
  void setMode(PriceMode mode) {
    if (mode == _mode && _lineModes.isEmpty) return;
    _mode = mode;
    _lineModes.clear();
    for (final id in _lines.keys.toList()) {
      final l = _lines[id]!;
      _lines[id] = _line(l.item, l.qty);
    }
    _fixDiscount();
    notifyListeners();
  }

  /// Sets retail or wholesale for one line only. Ignored when the item has no
  /// wholesale price. A manual price on the line is kept.
  void setLineMode(String id, PriceMode mode) {
    final l = _lines[id];
    if (l == null || !l.item.hasWholesale) return;
    _lineModes[id] = mode;
    _lines[id] = _line(l.item, l.qty);
    _fixDiscount();
    notifyListeners();
  }

  /// Sets a manual unit price for a line. Null or a negative value removes
  /// the override. A price equal to the current list price is not an override.
  void setOverride(String id, double? price) {
    final l = _lines[id];
    if (l == null) return;
    final list = (l.mode == PriceMode.wholesale && l.item.hasWholesale) ? l.item.wholesalePrice! : l.item.price;
    if (price == null || price < 0 || (price - list).abs() < 0.0001) {
      _overrides.remove(id);
    } else {
      _overrides[id] = price;
    }
    _lines[id] = _line(l.item, l.qty);
    _fixDiscount();
    notifyListeners();
  }

  void setTaxPercent(double percent) {
    _taxPercent = percent < 0 ? 0 : percent;
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discount = amount.clamp(0, subtotal).toDouble();
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _overrides.clear();
    _lineModes.clear();
    _discount = 0;
    _mode = PriceMode.retail;
    notifyListeners();
  }

  /// Plain data for saving. Items are stored by id only; prices are not saved
  /// so a restored cart always uses today's catalogue prices.
  Map<String, Object?> toJson() => {
        'mode': _mode.name,
        'discount': _discount,
        'lines': {for (final l in _lines.values) l.item.id: l.qty},
        'overrides': Map<String, double>.from(_overrides),
        'lineModes': {for (final e in _lineModes.entries) e.key: e.value.name},
      };

  /// Rebuilds the cart from [toJson] output. Items that no longer exist are
  /// skipped and quantities are capped to current stock. Returns how many
  /// lines were dropped or reduced so the screen can say so.
  int restoreFrom(Map<String, Object?> json, Map<String, CatalogueItem> catalogue) {
    _lines.clear();
    _overrides.clear();
    _lineModes.clear();
    _mode = json['mode'] == 'wholesale' ? PriceMode.wholesale : PriceMode.retail;
    var changed = 0;

    final overrides = json['overrides'];
    if (overrides is Map) {
      overrides.forEach((k, v) {
        if (v is num && v >= 0) _overrides[k.toString()] = v.toDouble();
      });
    }
    final modes = json['lineModes'];
    if (modes is Map) {
      modes.forEach((k, v) => _lineModes[k.toString()] = v == 'wholesale' ? PriceMode.wholesale : PriceMode.retail);
    }
    final lines = json['lines'];
    if (lines is Map) {
      lines.forEach((k, v) {
        final item = catalogue[k.toString()];
        final want = v is num ? v.toInt() : 0;
        if (item == null || want <= 0) {
          changed++;
          return;
        }
        final qty = want > item.stock ? item.stock.floor() : want;
        if (qty <= 0) {
          changed++;
          return;
        }
        if (qty < want) changed++;
        _lines[item.id] = _line(item, qty);
      });
    }
    _overrides.removeWhere((id, _) => !_lines.containsKey(id));
    _lineModes.removeWhere((id, _) => !_lines.containsKey(id));
    for (final id in _lines.keys.toList()) {
      _lines[id] = _line(_lines[id]!.item, _lines[id]!.qty);
    }
    final d = json['discount'];
    _discount = d is num ? d.toDouble().clamp(0, subtotal).toDouble() : 0;
    notifyListeners();
    return changed;
  }

  void _fixDiscount() {
    if (_discount > subtotal) _discount = subtotal;
  }
}

/// Several carts open at once, for a cashier serving more than one customer.
/// Always has at least one cart.
class CartSessions extends ChangeNotifier {
  CartSessions({this.taxPercent = 0}) {
    _add(_Named('Cart 1', CartState(taxPercent: taxPercent)));
  }

  /// Child carts notify this object too, so the cart strip and saving see
  /// every change.
  void _add(_Named n) {
    n.cart.addListener(notifyListeners);
    _carts.add(n);
  }

  final double taxPercent;
  final List<_Named> _carts = [];
  int _active = 0;
  int _counter = 1;

  CartState get active => _carts[_active].cart;
  int get activeIndex => _active;
  int get length => _carts.length;
  String labelAt(int i) => _carts[i].label;
  int countAt(int i) => _carts[i].cart.count;

  void create() {
    _counter++;
    _add(_Named('Cart $_counter', CartState(taxPercent: taxPercent)));
    _active = _carts.length - 1;
    notifyListeners();
  }

  void switchTo(int i) {
    if (i < 0 || i >= _carts.length || i == _active) return;
    _active = i;
    notifyListeners();
  }

  /// Closes a cart. The last one cannot be closed, only emptied.
  void close(int i) {
    if (_carts.length <= 1 || i < 0 || i >= _carts.length) return;
    final gone = _carts.removeAt(i);
    gone.cart.removeListener(notifyListeners);
    gone.cart.dispose();
    if (_active >= _carts.length) _active = _carts.length - 1;
    if (i < _active) _active--;
    notifyListeners();
  }

  bool get allEmpty => _carts.every((c) => c.cart.isEmpty);

  Map<String, Object?> toJson() => {
        'active': _active,
        'counter': _counter,
        'carts': [
          for (final c in _carts) {'label': c.label, 'cart': c.cart.toJson()},
        ],
      };

  /// Restores saved carts. Returns the number of lines dropped or reduced.
  int restoreFrom(Map<String, Object?> json, Map<String, CatalogueItem> catalogue) {
    final saved = json['carts'];
    if (saved is! List || saved.isEmpty) return 0;
    for (final c in _carts) {
      c.cart.removeListener(notifyListeners);
      c.cart.dispose();
    }
    _carts.clear();
    var changed = 0;
    for (final entry in saved) {
      if (entry is! Map) continue;
      final cart = CartState(taxPercent: taxPercent);
      final data = entry['cart'];
      if (data is Map) changed += cart.restoreFrom(Map<String, Object?>.from(data), catalogue);
      _add(_Named(entry['label']?.toString() ?? 'Cart', cart));
    }
    if (_carts.isEmpty) _add(_Named('Cart 1', CartState(taxPercent: taxPercent)));
    final a = json['active'];
    _active = a is int && a >= 0 && a < _carts.length ? a : 0;
    final n = json['counter'];
    _counter = n is int && n >= _carts.length ? n : _carts.length;
    notifyListeners();
    return changed;
  }

  @override
  void dispose() {
    for (final c in _carts) {
      c.cart.removeListener(notifyListeners);
      c.cart.dispose();
    }
    super.dispose();
  }
}

class _Named {
  _Named(this.label, this.cart);
  final String label;
  final CartState cart;
}

/// A saved customer the cashier can attach to a sale.
@immutable
class CustomerOption {
  const CustomerOption({required this.id, required this.name, this.phone, this.email});
  final String id;
  final String name;
  final String? phone;
  final String? email;
}

/// What the cashier chose in the checkout sheet.
@immutable
class CheckoutInput {
  const CheckoutInput({required this.method, this.customer, this.splits = const [], this.storeId, this.customerRef});

  /// Set when a saved customer was picked; [customer] then holds their name.
  final CustomerOption? customerRef;

  /// [PayMethod] for a single payment; null when the payment is split.
  final PayMethod? method;
  final String? customer;

  /// Non-empty only for a split payment; amounts add up to the total.
  final List<PaymentSplit> splits;
  final String? storeId;
}

@immutable
class StoreOption {
  const StoreOption(this.id, this.name);
  final String id;
  final String name;
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
    this.queuedOffline = false,
    this.splits = const [],
    this.tax = 0,
    this.discount = 0,
  });

  final String reference;
  final DateTime when;
  final List<CartLine> lines;
  final double total;
  final PayMethod? method;
  final String? customer;

  /// Saved on the device and waiting to upload.
  final bool queuedOffline;
  final List<PaymentSplit> splits;
  final double tax;
  final double discount;
}
