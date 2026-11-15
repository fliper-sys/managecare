import '../../../data/repositories/sales_repository_supabase.dart';

/// Seven-day sales picture for the Retail home.
class SalesWindow {
  const SalesWindow({
    required this.today,
    required this.yesterday,
    required this.todayCount,
    required this.daily,
  });

  final double today;
  final double yesterday;
  final int todayCount;

  /// Oldest first, last item is today. Always [days] long.
  final List<double> daily;

  static const empty = SalesWindow(today: 0, yesterday: 0, todayCount: 0, daily: [0, 0, 0, 0, 0, 0, 0]);

  /// Change against yesterday in percent. Zero when there is no baseline, so
  /// the UI never shows an infinite or misleading figure.
  double get deltaPercent => yesterday <= 0 ? 0 : (today - yesterday) / yesterday * 100;

  /// Builds the window from raw sale rows. Rows that are not completed, have
  /// no readable date, or fall outside the window are ignored.
  factory SalesWindow.fromRows(List<Map<String, dynamic>> rows, DateTime now, {int days = 7}) {
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final daily = List<double>.filled(days, 0);
    var todayCount = 0;
    for (final r in rows) {
      final status = r['status']?.toString().toLowerCase();
      if (status != null && status.isNotEmpty && status != 'completed') continue;
      final at = _date(r['created_at'] ?? r['createdAt']);
      if (at == null) continue;
      final day = DateTime(at.year, at.month, at.day);
      final i = day.difference(start).inDays;
      if (i < 0 || i >= days) continue;
      daily[i] += (r['final_amount'] as num?)?.toDouble() ?? 0;
      if (i == days - 1) todayCount++;
    }
    return SalesWindow(
      today: daily.last,
      yesterday: days > 1 ? daily[days - 2] : 0,
      todayCount: todayCount,
      daily: List.unmodifiable(daily),
    );
  }

  static DateTime? _date(Object? v) {
    if (v is DateTime) return v.toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    return null;
  }
}

/// One fetch for the whole window, so the home makes a single sales call.
Future<SalesWindow> fetchSalesWindow(String businessId, {DateTime? now, int days = 7}) async {
  final n = now ?? DateTime.now();
  final start = DateTime(n.year, n.month, n.day).subtract(Duration(days: days - 1));
  final rows = await SalesRepositorySupabase().fetchSales(
    businessId: businessId,
    start: start,
    end: DateTime(n.year, n.month, n.day, 23, 59, 59),
  );
  return SalesWindow.fromRows(rows, n, days: days);
}
