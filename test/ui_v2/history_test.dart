import 'dart:async';

import 'package:business_manager/features/retail/history/sale_summary.dart';
import 'package:business_manager/features/retail/history/sales_pager.dart';
import 'package:business_manager/shared_features/ui_v2_switch.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _sale(String id, {String? at, Map<String, dynamic>? extra}) =>
    {'id': id, if (at != null) 'createdAt': at, ...?extra};

void main() {
  group('saleAmount', () {
    test('uses the same field order as the old screen', () {
      expect(saleAmount({'totalAmount': 500, 'finalAmount': 400}), 500);
      expect(saleAmount({'finalAmount': '400.5'}), 400.5);
      expect(saleAmount({'total': 300}), 300);
      expect(saleAmount({'amount': 250}), 250);
      expect(saleAmount({'subtotal': 120}), 120);
    });

    test('falls back to summing line items', () {
      expect(
        saleAmount({
          'items': [
            {'total': 1000},
            {'quantity': 2, 'unitPrice': 250},
            {'quantity': 3, 'price': 100},
            'junk',
          ]
        }),
        1800,
      );
    });

    test('nothing usable gives zero', () => expect(saleAmount({}), 0));
  });

  group('productNames', () {
    test('names, quantities and fallbacks', () {
      final text = productNames({
        'items': [
          {'productName': 'Rice', 'quantity': 2},
          {'product_name': 'Oil'},
          {'name': 'Salt', 'qty': '3'},
          {'product': {'name': 'Sugar'}},
          {'productId': 'p9'},
          {'quantity': 1},
        ]
      }, nameForProduct: (id) => id == 'p9' ? 'Flour' : null);
      expect(text, 'Rice × 2, Oil, Salt × 3, Sugar, Flour, Unknown Product');
    });

    test('items stored as json text are read', () {
      expect(productNames({'items': ['{"productName":"Rice","quantity":2}']}), 'Rice × 2');
    });

    test('no items', () => expect(productNames({'items': []}), 'No items'));
  });

  group('SaleSummary', () {
    test('title uses the reference, else the last 8 characters of the id', () {
      expect(SaleSummary.fromMap({'referenceId': 'ABC-1'}, index: 0).title, 'Sale #ABC-1');
      expect(SaleSummary.fromMap({'id': '12345678-aaaa-bbbb-cccc-0123456789ab'}, index: 0).title, 'Sale #456789ab');
      expect(SaleSummary.fromMap({}, index: 4).title, 'SALE-5');
    });

    test('defaults match the old screen', () {
      final s = SaleSummary.fromMap({'id': 'x'}, index: 0);
      expect(s.customer, 'Walk-in Customer');
      expect(s.paymentMethod, 'Cash');
      expect(s.status, 'completed');
      expect(s.pendingSync, isFalse);
    });

    test('search covers reference, customer, products and id', () {
      final s = SaleSummary.fromMap({
        'id': 'zz11',
        'referenceId': 'R-77',
        'customerName': 'Mama Ngozi',
        'items': [
          {'productName': 'Palm oil'}
        ]
      }, index: 0);
      expect(s.matches('ngozi'), isTrue);
      expect(s.matches('PALM'), isTrue);
      expect(s.matches('r-77'), isTrue);
      expect(s.matches('zz11'), isTrue);
      expect(s.matches('cement'), isFalse);
      expect(s.matches('  '), isTrue);
    });

    test('refunded states', () {
      expect(SaleSummary.fromMap({'status': 'refunded'}, index: 0).isRefunded, isTrue);
      expect(SaleSummary.fromMap({'status': 'partially_refunded'}, index: 0).isPartiallyRefunded, isTrue);
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 11, 15, 12);
    test('buckets', () {
      expect(relativeTime(null, now: now), 'Just now');
      expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), '2d ago');
      expect(relativeTime(DateTime(2026, 10, 1), now: now), '1/10/2026');
    });
  });

  group('SalesPager', () {
    Map<String, dynamic> page(List<String> ids, {int? next}) => {
          'sales': [for (final i in ids) _sale(i, at: '2026-11-1${ids.indexOf(i)}T10:00:00')],
          'nextPage': next,
        };

    SalesPager make({
      required Future<Map<String, dynamic>> Function(int? page) pages,
      List<Map<String, dynamic>> local = const [],
      String filter = 'all',
      void Function(String? status)? onStatus,
    }) =>
        SalesPager(
          filter: filter,
          pageSize: 2,
          fetchPage: ({required limit, start, end, status, page}) {
            onStatus?.call(status);
            return pages(page);
          },
          fetchLocalPending: () async => local,
        );

    test('loads the first page, then more, until the end', () async {
      final p = make(pages: (n) async => n == null ? page(['a', 'b'], next: 2) : page(['c']));
      await p.reset();
      expect(p.items.map((s) => s['id']), ['a', 'b']);
      expect(p.hasMore, isTrue);
      await p.more();
      expect(p.items.map((s) => s['id']), ['a', 'b', 'c']);
      expect(p.hasMore, isFalse);
      await p.more(); // nothing left, no extra call
      expect(p.items.length, 3);
    });

    test('the all tab sends no status; other tabs send theirs', () async {
      String? seen = 'unset';
      await make(pages: (_) async => page([]), onStatus: (s) => seen = s).reset();
      expect(seen, isNull);
      await make(pages: (_) async => page([]), filter: 'refunded', onStatus: (s) => seen = s).reset();
      expect(seen, 'refunded');
    });

    test('offline sales are merged on the all and completed tabs, newest first, without duplicates', () async {
      final p = make(
        pages: (_) async => {
          'sales': [_sale('s1', at: '2026-11-10T10:00:00'), _sale('s2', at: '2026-11-08T10:00:00')],
          'nextPage': null,
        },
        local: [
          _sale('s1', at: '2026-11-10T10:00:00'), // already on the server
          _sale('off1', at: '2026-11-12T09:00:00', extra: {'pendingSync': true}),
        ],
      );
      await p.reset();
      expect(p.items.map((s) => s['id']), ['off1', 's1', 's2']);
    });

    test('offline sales outside the date range are left out; refunded tab has none', () async {
      final local = [_sale('off1', at: '2026-11-01T09:00:00')];
      final p = make(pages: (_) async => page([]), local: local);
      await p.reset(start: DateTime(2026, 11, 5), end: DateTime(2026, 11, 20));
      expect(p.items, isEmpty);
      final r = make(pages: (_) async => page([]), local: local, filter: 'refunded');
      await r.reset();
      expect(r.items, isEmpty);
    });

    test('a failure sets the error and keeps the screen usable; a retry clears it', () async {
      var fail = true;
      final p = make(pages: (_) async {
        if (fail) throw Exception('network');
        return page(['a']);
      });
      await p.reset();
      expect(p.error, contains('network'));
      expect(p.loading, isFalse);
      fail = false;
      await p.reset();
      expect(p.error, isNull);
      expect(p.items.length, 1);
    });

    test('a slow older load cannot overwrite a newer one', () async {
      final slow = Completer<Map<String, dynamic>>();
      var call = 0;
      final p = make(pages: (_) {
        call++;
        return call == 1 ? slow.future : Future.value(page(['new']));
      });
      final first = p.reset();
      await p.reset();
      slow.complete(page(['old']));
      await first;
      expect(p.items.map((s) => s['id']), ['new']);
    });

    test('a broken device database does not hide server sales', () async {
      final p = SalesPager(
        filter: 'all',
        fetchPage: ({required limit, start, end, status, page}) async => this_page(),
        fetchLocalPending: () async => throw Exception('db'),
      );
      await p.reset();
      expect(p.items.length, 1);
    });

    test('removeById drops one sale', () async {
      final p = make(pages: (_) async => page(['a', 'b']));
      await p.reset();
      p.removeById('a');
      expect(p.items.map((s) => s['id']), ['b']);
    });
  });

  group('UiV2Switch.useV2', () {
    test('needs the right business type and the flag', () {
      expect(UiV2Switch.useV2('retail', 'retail', buildFlag: 'retail'), isTrue);
      expect(UiV2Switch.useV2(' Retail ', 'retail', buildFlag: 'all'), isTrue);
      expect(UiV2Switch.useV2('bakery', 'retail', buildFlag: 'all'), isFalse);
      expect(UiV2Switch.useV2('retail', 'retail', buildFlag: ''), isFalse);
      expect(UiV2Switch.useV2(null, 'retail', buildFlag: 'all'), isFalse);
    });
  });
}

Map<String, dynamic> this_page() => {
      'sales': [
        {'id': 'z', 'createdAt': '2026-11-10T10:00:00'}
      ],
      'nextPage': null,
    };
