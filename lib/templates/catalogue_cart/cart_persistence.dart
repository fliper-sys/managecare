import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cart_models.dart';

/// Where saved carts live. The app passes a SharedPreferences-backed store;
/// tests pass a map.
abstract class CartStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class MemoryCartStore implements CartStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

/// Saves the open carts a moment after every change and restores them when
/// the POS reopens. One instance per business (key the store by business id),
/// so carts never cross businesses.
class CartPersistence {
  CartPersistence(this.sessions, this.store, {this.delay = const Duration(milliseconds: 400)}) {
    sessions.addListener(_changed);
  }

  final CartSessions sessions;
  final CartStore store;
  final Duration delay;
  Timer? _timer;
  bool _restoring = false;
  bool _disposed = false;

  void _changed() {
    if (_restoring || _disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Writes now. An all-empty state clears the saved copy instead.
  Future<void> flush() async {
    _timer?.cancel();
    if (_disposed) return;
    try {
      await store.write(sessions.allEmpty && sessions.length == 1 ? null : jsonEncode(sessions.toJson()));
    } catch (e) {
      debugPrint('[CartPersistence] save failed: $e');
    }
  }

  /// Restores saved carts once the catalogue is known. Does nothing when the
  /// cashier has already started a cart. Returns lines dropped or reduced,
  /// or -1 when nothing was restored.
  Future<int> restore(Map<String, CatalogueItem> catalogue) async {
    if (!sessions.allEmpty) return -1;
    try {
      final raw = await store.read();
      if (raw == null || raw.isEmpty) return -1;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return -1;
      _restoring = true;
      return sessions.restoreFrom(Map<String, Object?>.from(decoded), catalogue);
    } catch (e) {
      debugPrint('[CartPersistence] restore failed: $e');
      return -1;
    } finally {
      _restoring = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    sessions.removeListener(_changed);
  }
}
