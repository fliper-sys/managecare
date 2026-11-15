import 'package:business_manager/features/retail/home/retail_sales_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _r(DateTime at, num amt, {String? status}) =>
    {'created_at': at.toIso8601String(), 'final_amount': amt, if (status != null) 'status': status};

void main() {
  final now = DateTime(2026, 11, 15, 12);

  test('buckets by day, today last', () {
    final w = SalesWindow.fromRows([
      _r(DateTime(2026, 11, 15, 9), 1000),
      _r(DateTime(2026, 11, 15, 10), 500),
      _r(DateTime(2026, 11, 14, 9), 1000),
      _r(DateTime(2026, 11, 9, 9), 200),
    ], now);
    expect(w.today, 1500);
    expect(w.todayCount, 2);
    expect(w.yesterday, 1000);
    expect(w.daily.length, 7);
    expect(w.daily.first, 200);
    expect(w.deltaPercent, 50);
  });

  test('ignores cancelled, undated and out-of-window rows', () {
    final w = SalesWindow.fromRows([
      _r(DateTime(2026, 11, 15, 9), 900, status: 'cancelled'),
      {'final_amount': 100},
      _r(DateTime(2026, 11, 1), 700),
      _r(DateTime(2026, 11, 16), 700),
    ], now);
    expect(w.daily.every((d) => d == 0), isTrue);
    expect(w.todayCount, 0);
  });

  test('no yesterday baseline gives zero delta, not infinity', () {
    final w = SalesWindow.fromRows([_r(DateTime(2026, 11, 15, 9), 800)], now);
    expect(w.deltaPercent, 0);
  });

  test('falling sales give a negative delta', () {
    final w = SalesWindow.fromRows([
      _r(DateTime(2026, 11, 15, 9), 500),
      _r(DateTime(2026, 11, 14, 9), 1000),
    ], now);
    expect(w.deltaPercent, -50);
  });
}
