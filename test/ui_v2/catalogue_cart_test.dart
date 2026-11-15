import 'package:business_manager/business_profiles/business_profiles.dart';
import 'package:business_manager/design/components/components.dart';
import 'package:business_manager/templates/catalogue_cart/catalogue_cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _rice = CatalogueItem(id: 'r', name: 'Rice 50kg', price: 45000, stock: 3, category: 'Grains');
const _oil = CatalogueItem(id: 'o', name: 'Palm oil', price: 2500, stock: 40, category: 'Oils');
const _gone = CatalogueItem(id: 'g', name: 'Salt', price: 300, stock: 0, category: 'Oils');
final _terms = retailProfile.terms;

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: reduce), child: w!),
      home: Scaffold(body: child),
    );

void main() {
  group('CartState', () {
    test('adds, counts and totals', () {
      final c = CartState();
      expect(c.add(_oil), isTrue);
      expect(c.add(_oil), isTrue);
      expect(c.add(_rice), isTrue);
      expect(c.count, 3);
      expect(c.subtotal, 50000);
    });

    test('stops at stock', () {
      final c = CartState();
      for (var i = 0; i < 3; i++) {
        expect(c.add(_rice), isTrue);
      }
      expect(c.add(_rice), isFalse);
      expect(c.qtyOf('r'), 3);
      expect(c.add(_gone), isFalse);
    });

    test('decrement removes at zero', () {
      final c = CartState()..add(_oil);
      c.decrement('o');
      expect(c.isEmpty, isTrue);
    });

    test('discount is clamped and follows the subtotal down', () {
      final c = CartState()..add(_oil)..add(_oil);
      c.setDiscount(99999);
      expect(c.discount, 5000);
      expect(c.total, 0);
      c.decrement('o');
      expect(c.discount, 2500);
      c.setDiscount(-5);
      expect(c.discount, 0);
    });

    test('clear resets everything', () {
      final c = CartState()..add(_oil);
      c.setDiscount(100);
      c.clear();
      expect(c.isEmpty && c.discount == 0, isTrue);
    });
  });

  group('CatalogueCartView', () {
    Widget view(CartState c, {List<CatalogueItem> items = const [_rice, _oil, _gone], bool loading = false, VoidCallback? onCheckout, ValueChanged<CatalogueItem>? oos}) =>
        _app(CatalogueCartView(items: items, cart: c, terms: _terms, accent: Colors.teal, onCheckout: onCheckout ?? () {}, isLoading: loading, onOutOfStock: oos));

    testWidgets('search and category filter', (tester) async {
      await tester.pumpWidget(view(CartState()));
      expect(find.text('Rice 50kg'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'palm');
      await tester.pump();
      expect(find.text('Rice 50kg'), findsNothing);
      expect(find.text('Palm oil'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Nothing matches'), findsOneWidget);
    });

    testWidgets('add shows the cart bar, sold out cannot be added', (tester) async {
      final c = CartState();
      await tester.pumpWidget(view(c));
      expect(find.textContaining('Sold out'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pump();
      expect(c.count, 1);
      expect(find.textContaining('₦45,000'), findsWidgets);
    });

    testWidgets('empty catalogue and loading states', (tester) async {
      await tester.pumpWidget(view(CartState(), items: const []));
      expect(find.textContaining('No products yet'), findsOneWidget);
      await tester.pumpWidget(view(CartState(), loading: true));
      expect(find.byType(SkeletonBlock), findsWidgets);
      expect(find.text('Rice 50kg'), findsNothing);
    });
  });

  group('CheckoutSheet', () {
    SaleReceipt receipt(CartState c, PayMethod m) => SaleReceipt(reference: 'R-1', when: DateTime(2026, 11, 15), lines: c.lines, total: c.total, method: m);

    testWidgets('success path clears cart and shows receipt', (tester) async {
      final c = CartState()..add(_oil);
      PayMethod? sent;
      await tester.pumpWidget(_app(CheckoutSheet(
        cart: c, terms: _terms, accent: Colors.teal,
        onComplete: (m, name) async {
          sent = m;
          return receipt(c, m);
        },
      ), reduce: true));
      await tester.tap(find.text('Transfer'));
      await tester.pump();
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(sent, PayMethod.transfer);
      expect(c.isEmpty, isTrue);
      expect(find.text('Sale recorded'), findsOneWidget);
      expect(find.text('Ref R-1'), findsOneWidget);
    });

    testWidgets('failure keeps the cart and offers retry; double tap sends once', (tester) async {
      final c = CartState()..add(_oil);
      var calls = 0;
      await tester.pumpWidget(_app(CheckoutSheet(
        cart: c, terms: _terms, accent: Colors.teal,
        onComplete: (m, name) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          throw Exception('network');
        },
      ), reduce: true));
      await tester.tap(find.text('Complete sale'));
      await tester.pump();
      await tester.tap(find.text('Recording…'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(calls, 1);
      expect(c.isEmpty, isFalse);
      expect(find.textContaining('Nothing was charged'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
