import 'package:flutter/foundation.dart';

typedef FetchSalesPage = Future<Map<String, dynamic>> Function({
  required int limit,
  DateTime? start,
  DateTime? end,
  String? status,
  int? page,
});

/// Loads one tab of sales history page by page. Pure Dart apart from
/// [ChangeNotifier], so it is tested with fake fetchers.
///
/// The first page of the "all" and "completed" tabs also merges sales that
/// only exist on the device (made offline, not uploaded yet), as the old
/// screen did; otherwise they would be invisible until the sync ran.
class SalesPager extends ChangeNotifier {
  SalesPager({
    required this.filter,
    required this.fetchPage,
    required this.fetchLocalPending,
    this.pageSize = 30,
  });

  final String filter;
  final FetchSalesPage fetchPage;
  final Future<List<Map<String, dynamic>>> Function() fetchLocalPending;
  final int pageSize;

  List<Map<String, dynamic>> items = [];
  int? _next;
  bool loading = false;
  bool loadingMore = false;
  String? error;
  int _generation = 0;

  bool get hasMore => _next != null;

  /// Loads the first page. A newer reset makes an older, slower one a no-op.
  Future<void> reset({DateTime? start, DateTime? end}) async {
    final gen = ++_generation;
    loading = true;
    error = null;
    items = [];
    _next = null;
    notifyListeners();
    try {
      final page = await fetchPage(limit: pageSize, start: start, end: end, status: filter == 'all' ? null : filter, page: null);
      var list = _sales(page);
      if (filter == 'all' || filter == 'completed') {
        try {
          list = _mergePending(list, await fetchLocalPending(), start, end);
        } catch (_) {
          // The device copy is a bonus; the server list still shows.
        }
      }
      if (gen != _generation) return;
      items = list;
      _next = page['nextPage'] as int?;
    } catch (e) {
      if (gen != _generation) return;
      error = 'Error loading sales: $e';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> more({DateTime? start, DateTime? end}) async {
    if (loadingMore || loading || _next == null) return;
    final gen = _generation;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await fetchPage(limit: pageSize, start: start, end: end, status: filter == 'all' ? null : filter, page: _next);
      if (gen != _generation) return;
      items = [...items, ..._sales(page)];
      _next = page['nextPage'] as int?;
    } catch (e) {
      if (gen != _generation) return;
      error = 'Error loading sales: $e';
    }
    loadingMore = false;
    notifyListeners();
  }

  void removeById(String id) {
    items = items.where((s) => s['id']?.toString() != id).toList();
    notifyListeners();
  }

  static List<Map<String, dynamic>> _sales(Map<String, dynamic> page) =>
      (page['sales'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  static int _millis(dynamic v) => v is String ? (DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0) : 0;

  static List<Map<String, dynamic>> _mergePending(
    List<Map<String, dynamic>> server,
    List<Map<String, dynamic>> local,
    DateTime? start,
    DateTime? end,
  ) {
    final have = server.map((s) => s['id']).toSet();
    final extra = local.where((s) {
      if (have.contains(s['id'])) return false;
      final raw = s['createdAt'];
      final dt = raw is String ? DateTime.tryParse(raw) : null;
      if (dt == null) return true;
      if (start != null && dt.isBefore(start)) return false;
      if (end != null && dt.isAfter(end)) return false;
      return true;
    }).toList();
    if (extra.isEmpty) return server;
    return [...extra, ...server]..sort((a, b) => _millis(b['createdAt']).compareTo(_millis(a['createdAt'])));
  }
}
