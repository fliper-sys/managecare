import 'package:business_manager/business_profiles/business_profiles.dart';
import 'package:business_manager/design/components/components.dart';
import 'package:business_manager/design/format.dart';
import 'package:business_manager/design/naira_input_formatter.dart';
import 'package:business_manager/templates/catalogue_cart/catalogue_cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _rice = CatalogueItem(id: 'r', name: 'Rice 50kg', price: 45000, stock: 3, category: 'Grains');
const _oil = CatalogueItem(id: 'o', name: 'Palm oil', price: 2500, stock: 40, category: 'Oils');
const _flour = CatalogueItem(id: 'f', name: 'Flour 25kg', price: 20000, wholesalePrice: 18500, stock: 100, category: 'Grains');
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


  group('pricing, tax, overrides', () {
    test('wholesale mode uses wholesale price where it exists', () {
      final c = CartState()..add(_flour)..add(_oil);
      expect(c.subtotal, 22500);
      c.setMode(PriceMode.wholesale);
      expect(c.lineOf('f')!.unitPrice, 18500);
      expect(c.lineOf('o')!.unitPrice, 2500); // no wholesale price, stays retail
      expect(c.subtotal, 21000);
      c.setMode(PriceMode.retail);
      expect(c.subtotal, 22500);
    });

    test('custom price replaces the list price and survives a mode change', () {
      final c = CartState()..add(_flour);
      c.setOverride('f', 19250.5);
      expect(c.lineOf('f')!.overridden, isTrue);
      expect(c.subtotal, 19250.5);
      c.setMode(PriceMode.wholesale);
      expect(c.subtotal, 19250.5);
      expect(c.overrides, {'f': 19250.5});
    });

    test('custom price equal to list price is not an override; reset works', () {
      final c = CartState()..add(_flour);
      c.setOverride('f', 20000);
      expect(c.overrides, isEmpty);
      c.setOverride('f', 15000);
      c.setOverride('f', null);
      expect(c.lineOf('f')!.unitPrice, 20000);
      expect(c.lineOf('f')!.overridden, isFalse);
    });

    test('override applies to every unit added later', () {
      final c = CartState()..add(_flour);
      c.setOverride('f', 19000);
      c.add(_flour);
      expect(c.lineOf('f')!.qty, 2);
      expect(c.subtotal, 38000);
    });

    test('removing a line drops its override', () {
      final c = CartState()..add(_flour);
      c.setOverride('f', 19000);
      c.remove('f');
      expect(c.overrides, isEmpty);
    });

    test('tax is added, discount subtracted, never below zero', () {
      final c = CartState(taxPercent: 7.5)..add(_flour);
      expect(c.taxAmount, 1500);
      expect(c.total, 21500);
      c.setDiscount(1500);
      expect(c.total, 20000);
      c.setDiscount(999999);
      expect(c.discount, 20000);
      expect(c.total, 1500);
    });
  });


  group('per-line mode', () {
    test('one line can be wholesale while the cart stays retail', () {
      final c = CartState()..add(_flour)..add(_flour);
      final other = const CatalogueItem(id: 'x', name: 'Sugar', price: 1000, wholesalePrice: 900, stock: 50);
      c.add(other);
      c.setLineMode('f', PriceMode.wholesale);
      expect(c.mode, PriceMode.retail);
      expect(c.lineOf('f')!.unitPrice, 18500);
      expect(c.lineOf('x')!.unitPrice, 1000);
      c.add(_flour); // a later unit keeps the line's mode
      expect(c.lineOf('f')!.unitPrice, 18500);
    });

    test('items without a wholesale price ignore the line toggle; cart mode resets lines', () {
      final c = CartState()..add(_oil)..add(_flour);
      c.setLineMode('o', PriceMode.wholesale);
      expect(c.lineOf('o')!.mode, PriceMode.retail);
      c.setLineMode('f', PriceMode.wholesale);
      c.setMode(PriceMode.retail);
      expect(c.lineOf('f')!.unitPrice, 20000);
    });
  });

  group('saving and restoring carts', () {
    final catalogue = {for (final i in [_rice, _oil, _flour]) i.id: i};

    test('round trip keeps lines, custom prices, modes, discount, labels and active cart', () {
      final s = CartSessions(taxPercent: 7.5);
      s.active..add(_flour)..add(_flour)..setOverride('f', 19000)..setDiscount(500);
      s.create();
      s.active..add(_oil)..setLineMode('o', PriceMode.retail);
      final json = Map<String, Object?>.from(s.toJson());

      final back = CartSessions(taxPercent: 7.5);
      final changed = back.restoreFrom(json, catalogue);
      expect(changed, 0);
      expect(back.length, 2);
      expect(back.activeIndex, 1);
      expect(back.labelAt(1), 'Cart 2');
      expect(back.active.qtyOf('o'), 1);
      back.switchTo(0);
      expect(back.active.qtyOf('f'), 2);
      expect(back.active.lineOf('f')!.unitPrice, 19000);
      expect(back.active.discount, 500);
    });

    test('items that vanished or lost stock are dropped or reduced and counted', () {
      final s = CartSessions();
      s.active..add(_rice)..add(_rice)..add(_rice)..add(_oil);
      final json = Map<String, Object?>.from(s.toJson());
      final shrunk = {
        'r': const CatalogueItem(id: 'r', name: 'Rice 50kg', price: 45000, stock: 1),
        // oil is gone
      };
      final back = CartSessions();
      expect(back.restoreFrom(json, shrunk), 2);
      expect(back.active.qtyOf('r'), 1);
      expect(back.active.qtyOf('o'), 0);
    });

    test('restored cart uses today\'s catalogue price, not the old one', () {
      final s = CartSessions();
      s.active.add(_oil);
      final json = Map<String, Object?>.from(s.toJson());
      final dearer = {'o': const CatalogueItem(id: 'o', name: 'Palm oil', price: 3000, stock: 40)};
      final back = CartSessions()..restoreFrom(json, dearer);
      expect(back.active.subtotal, 3000);
    });

    test('garbage json restores nothing and does not throw', () {
      final back = CartSessions();
      expect(back.restoreFrom({'carts': 'nope'}, catalogue), 0);
      expect(back.length, 1);
    });

    test('child cart changes notify the sessions object', () {
      final s = CartSessions();
      var n = 0;
      s.addListener(() => n++);
      s.active.add(_oil);
      expect(n, 1);
      expect(s.countAt(0), 1);
    });

    test('persistence saves after a change and restores into a fresh session', () async {
      final store = MemoryCartStore();
      final s = CartSessions();
      final p = CartPersistence(s, store, delay: Duration.zero);
      s.active.add(_oil);
      await p.flush();
      expect(store.value, isNotNull);
      p.dispose();

      final s2 = CartSessions();
      final p2 = CartPersistence(s2, store, delay: Duration.zero);
      expect(await p2.restore(catalogue), 0);
      expect(s2.active.qtyOf('o'), 1);
      p2.dispose();
    });

    test('an emptied cart clears the saved copy; a started cart is not overwritten', () async {
      final store = MemoryCartStore();
      final s = CartSessions();
      final p = CartPersistence(s, store, delay: Duration.zero);
      s.active.add(_oil);
      await p.flush();
      s.active.clear();
      await p.flush();
      expect(store.value, isNull);

      store.value = '{"carts":[{"label":"Old","cart":{"lines":{"o":1}}}],"active":0,"counter":1}';
      s.active.add(_rice);
      expect(await p.restore(catalogue), -1); // cashier already started
      expect(s.active.qtyOf('r'), 1);
      p.dispose();
    });
  });

  group('CartSessions', () {
    test('create, switch, close keep carts separate', () {
      final s = CartSessions();
      s.active.add(_oil);
      s.create();
      expect(s.length, 2);
      expect(s.active.isEmpty, isTrue);
      s.active.add(_rice);
      s.switchTo(0);
      expect(s.active.qtyOf('o'), 1);
      expect(s.active.qtyOf('r'), 0);
      s.close(1);
      expect(s.length, 1);
      s.close(0); // last cart cannot be closed
      expect(s.length, 1);
    });

    test('closing an earlier cart keeps the same cart active', () {
      final s = CartSessions()..create()..create();
      s.active.add(_oil); // cart 3 is active
      s.close(0);
      expect(s.active.qtyOf('o'), 1);
    });
  });

  group('currency formatting', () {
    test('formatNairaPrecise keeps kobo only when present', () {
      expect(formatNairaPrecise(45000), '₦45,000');
      expect(formatNairaPrecise(1250.5), '₦1,250.50');
      expect(formatNairaPrecise(0.05), '₦0.05');
      expect(formatNairaPrecise(1234567.89), '₦1,234,567.89');
      expect(formatNairaPrecise(-2500.25), '-₦2,500.25');
    });

    test('parseNaira ignores commas, spaces and the sign', () {
      expect(parseNaira('₦ 1,250.50'), 1250.5);
      expect(parseNaira(''), isNull);
      expect(parseNaira('abc'), isNull);
    });

    test('input formatter groups thousands and limits kobo', () {
      const f = NairaInputFormatter();
      String fmt(String t) => f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t)).text;
      expect(fmt('1250000'), '1,250,000');
      expect(fmt('1250.567'), '1,250.56');
      expect(fmt('007'), '7');
      expect(fmt('.5'), '0.5');
      expect(fmt('12a3'), '123');
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


    testWidgets('wholesale toggle shows only when an item has a wholesale price', (tester) async {
      await tester.pumpWidget(view(CartState()));
      expect(find.text('Wholesale'), findsNothing);
      await tester.pumpWidget(view(CartState(), items: const [_flour, _oil]));
      expect(find.text('Wholesale'), findsOneWidget);
      await tester.tap(find.text('Wholesale'));
      await tester.pump();
      expect(find.text('₦18,500'), findsOneWidget);
    });

    testWidgets('price of a line in the cart can be edited from the catalogue', (tester) async {
      final c = CartState()..add(_flour);
      await tester.pumpWidget(view(c, items: const [_flour]));
      await tester.tap(find.widgetWithText(TactilePressable, '₦20,000').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '19250.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(c.lineOf('f')!.unitPrice, 19250.5);
      expect(find.text('₦19,250.50'), findsWidgets);
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
    SaleReceipt receipt(CartState c, PayMethod? m, {List<PaymentSplit> splits = const [], bool queued = false}) => SaleReceipt(reference: 'R-1', when: DateTime(2026, 11, 15), lines: c.lines, total: c.total, method: m, splits: splits, queuedOffline: queued);

    testWidgets('success path clears cart and shows receipt', (tester) async {
      final c = CartState()..add(_oil);
      PayMethod? sent;
      await tester.pumpWidget(_app(CheckoutSheet(
        cart: c, terms: _terms, accent: Colors.teal,
        onComplete: (i) async {
          sent = i.method;
          return receipt(c, i.method);
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
        onComplete: (i) async {
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

    testWidgets('split payment needs to add up before it can be submitted', (tester) async {
      final c = CartState()..add(_oil)..add(_oil); // 5,000
      CheckoutInput? got;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: CheckoutSheet(
          cart: c, terms: _terms, accent: Colors.teal,
          onComplete: (i) async {
            got = i;
            return receipt(c, null, splits: i.splits);
          },
        ),
      ), reduce: true));
      await tester.tap(find.text('Split'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Cash'), '3000');
      await tester.enterText(find.widgetWithText(TextField, 'Card'), '1000');
      await tester.pump();
      expect(find.textContaining('Short by ₦1,000'), findsOneWidget);
      await tester.tap(find.text('Complete sale'), warnIfMissed: false);
      await tester.pump();
      expect(got, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Transfer'), '1000');
      await tester.pump();
      expect(find.text('Adds up to the total.'), findsOneWidget);
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(got!.method, isNull);
      expect(got!.splits.map((s) => s.amount), [3000, 1000, 1000]);
    });

    testWidgets('queued-offline sale says it is saved on the device', (tester) async {
      final c = CartState()..add(_oil);
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: CheckoutSheet(
          cart: c, terms: _terms, accent: Colors.teal,
          onComplete: (i) async => receipt(c, i.method, queued: true),
        ),
      ), reduce: true));
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved on this device'), findsOneWidget);
    });

    testWidgets('store choice is sent with the sale', (tester) async {
      final c = CartState()..add(_oil);
      String? store;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: CheckoutSheet(
          cart: c, terms: _terms, accent: Colors.teal,
          stores: const [StoreOption('s1', 'Main'), StoreOption('s2', 'Branch')],
          onComplete: (i) async {
            store = i.storeId;
            return receipt(c, i.method);
          },
        ),
      ), reduce: true));
      await tester.tap(find.text('Branch'));
      await tester.pump();
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(store, 's2');
    });

    testWidgets('picking a saved customer sends their id and name', (tester) async {
      final c = CartState()..add(_oil);
      CheckoutInput? got;
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: CheckoutSheet(
          cart: c, terms: _terms, accent: Colors.teal,
          customers: const [
            CustomerOption(id: 'c1', name: 'Mama Ngozi', phone: '0803'),
            CustomerOption(id: 'c2', name: 'Chidi', phone: '0701'),
          ],
          onComplete: (i) async {
            got = i;
            return receipt(c, i.method);
          },
        ),
      ), reduce: true));
      expect(find.text('Walk-in'), findsOneWidget);
      await tester.tap(find.text('Walk-in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'chi');
      await tester.pump();
      expect(find.text('Mama Ngozi'), findsNothing);
      await tester.tap(find.text('Chidi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete sale'));
      await tester.pumpAndSettle();
      expect(got!.customerRef?.id, 'c2');
      expect(got!.customer, 'Chidi');
    });

    testWidgets('line mode chips change the price in the review', (tester) async {
      final c = CartState()..add(_flour);
      await tester.pumpWidget(_app(SingleChildScrollView(
        child: CheckoutSheet(cart: c, terms: _terms, accent: Colors.teal, onComplete: (i) async => receipt(c, i.method)),
      ), reduce: true));
      await tester.tap(find.text('Wholesale'));
      await tester.pump();
      expect(c.lineOf('f')!.unitPrice, 18500);
      expect(find.textContaining('₦18,500'), findsWidgets);
    });
  });
}
