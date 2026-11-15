import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../business_profiles/business_profiles.dart';
import '../../../core/utils/receipt_utility.dart';
import '../../../design/ambient_background.dart';
import '../../../design/app_tokens.dart';
import '../../../design/app_type.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/retail_provider.dart';
import '../../../shared_features/session/tenant_scope.dart';
import '../../../templates/catalogue_cart/catalogue_cart.dart';

/// Retail point of sale on v2. Reached only through `UiV2.enabledFor('retail')`.
///
/// The v2 cart is the screen's own [CartState]; at checkout it is copied into
/// the existing provider cart and `RetailProvider.checkout` does the stock
/// check, pricing, offline queue and upload, so those rules stay in one place.
class RetailPosScreen extends StatelessWidget {
  const RetailPosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final id = context.select<BusinessProvider, String?>((p) => p.currentBusiness?.id);
    if (id == null) return const SizedBox.shrink();
    return TenantScope(tenantId: id, child: const _PosBody());
  }
}

class _PosBody extends StatefulWidget {
  const _PosBody();
  @override
  State<_PosBody> createState() => _PosBodyState();
}

class _PosBodyState extends State<_PosBody> {
  late final CartSessions _sessions = CartSessions(taxPercent: _taxPercent());

  double _taxPercent() => context.read<BusinessProvider>().currentBusiness?.taxRate ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<BusinessProvider>().currentBusiness?.id;
      if (id != null) context.read<RetailProvider>().initialize(id);
    });
  }

  @override
  void dispose() {
    _sessions.dispose();
    super.dispose();
  }

  List<CatalogueItem> _items(RetailProvider r) => [
        for (final p in r.products)
          CatalogueItem(
            id: p.id,
            name: p.name,
            price: p.price,
            stock: p.stock,
            category: p.category,
            unit: p.unit,
            wholesalePrice: p.hasWholesalePricing ? p.wholesalePrice : null,
          ),
      ];

  static String _name(PayMethod m) => switch (m) {
        PayMethod.cash => 'Cash',
        PayMethod.transfer => 'Transfer',
        PayMethod.card => 'Card',
        PayMethod.credit => 'Credit',
      };

  /// Copies the v2 cart into the provider cart, records the sale, and builds
  /// the receipt. A failure leaves the provider cart empty again.
  Future<SaleReceipt> _complete(CartState cart, CheckoutInput input) async {
    final retail = context.read<RetailProvider>();
    final auth = context.read<AuthProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;
    final lines = cart.lines;
    final total = cart.total;
    final tax = cart.taxAmount;
    final discount = cart.discount;
    final overrides = cart.overrides;
    final split = input.splits.isNotEmpty;

    retail.clearCart();
    bool queued;
    try {
      for (final l in lines) {
        retail.addToCart(l.item.id, qty: l.qty, pricingMode: l.mode.name);
      }
      queued = await retail.checkout(
        // Same strings the old POS sends: a capitalised name, or Mixed with a
        // lower-case breakdown.
        paymentMethod: split ? 'Mixed' : _name(input.method!),
        paymentBreakdown: split
            ? [for (final s in input.splits) {'method': s.method.name, 'amount': s.amount}]
            : [
                {'method': input.method!.name, 'amount': total}
              ],
        tax: cart.taxPercent,
        discount: discount,
        priceOverrides: overrides.isEmpty ? null : overrides,
        storeId: input.storeId,
        customerName: input.customer,
        workerId: auth.currentUser?.id,
        workerName: auth.currentUser?.name,
      );
    } catch (_) {
      retail.clearCart();
      rethrow;
    }
    return SaleReceipt(
      reference: ReceiptUtility.generateReferenceId(business?.name),
      when: DateTime.now(),
      lines: lines,
      total: total,
      method: split ? null : input.method,
      splits: input.splits,
      customer: input.customer,
      queuedOffline: queued,
      tax: tax,
      discount: discount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = context.select<BusinessProvider, String?>((p) => p.currentBusiness?.id);
    if (id == null) return const SizedBox.shrink();
    return TenantScope(tenantId: id, child: const _PosBody());
  }
}

class _PosBody extends StatefulWidget {
  const _PosBody();
  @override
  State<_PosBody> createState() => _PosBodyState();
}

class _PosBodyState extends State<_PosBody> {
  late final CartSessions _sessions = CartSessions(taxPercent: _taxPercent());

  double _taxPercent() => context.read<BusinessProvider>().currentBusiness?.taxRate ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<BusinessProvider>().currentBusiness?.id;
      if (id != null) context.read<RetailProvider>().initialize(id);
    });
  }

  @override
  void dispose() {
    _sessions.dispose();
    super.dispose();
  }

  List<CatalogueItem> _items(RetailProvider r) => [
        for (final p in r.products)
          CatalogueItem(
            id: p.id,
            name: p.name,
            price: p.price,
            stock: p.stock,
            category: p.category,
            unit: p.unit,
            wholesalePrice: p.hasWholesalePricing ? p.wholesalePrice : null,
          ),
      ];

  /// Copies the v2 cart into the provider cart, records the sale, and builds
  /// the receipt. A failure leaves the provider cart empty again.
  Future<SaleReceipt> _complete(PayMethod method, String? customer) async {
    final retail = context.read<RetailProvider>();
    final auth = context.read<AuthProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;
    final lines = _cart.lines;
    final total = _cart.total;
    final discount = _cart.discount;

    retail.clearCart();
    try {
      for (final l in lines) {
        retail.addToCart(l.item.id, qty: l.qty);
      }
      await retail.checkout(
        paymentMethod: switch (method) {
          PayMethod.cash => 'Cash',
          PayMethod.transfer => 'Transfer',
          PayMethod.card => 'Card',
          PayMethod.credit => 'Credit',
        },
        discount: discount,
        customerName: customer,
        workerId: auth.currentUser?.id,
        workerName: auth.currentUser?.name,
      );
    } catch (_) {
      retail.clearCart();
      rethrow;
    }
    return SaleReceipt(
      reference: ReceiptUtility.generateReferenceId(business?.name),
      when: DateTime.now(),
      lines: lines,
      total: total,
      method: method,
      customer: customer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final retail = context.watch<RetailProvider>();
    final profile = BusinessProfiles.forType('retail')!;

    return Scaffold(
      body: AmbientBackground(
        accent: profile.accent,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTokens.s4, AppTokens.s4, AppTokens.s16, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back_rounded, color: t.ink),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Text(profile.terms.newSale, style: AppType.sans(size: 20, weight: FontWeight.w800, color: t.ink)),
              ]),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _sessions,
                builder: (context, _) => CatalogueCartView(
                key: ValueKey(_sessions.activeIndex),
                sessions: _sessions,
                items: _items(retail),
                cart: _sessions.active,
                terms: profile.terms,
                accent: profile.accent,
                isLoading: retail.isLoading && retail.products.isEmpty,
                onOutOfStock: (item) => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('No more ${item.name} in stock'))),
                onCheckout: () {
                  final cart = _sessions.active;
                  showCheckoutSheet(
                    context,
                    cart: cart,
                    terms: profile.terms,
                    accent: profile.accent,
                    methods: const [PayMethod.cash, PayMethod.transfer, PayMethod.card],
                    stores: [for (final s in retail.stores) StoreOption(s.id, s.name)],
                    onComplete: (input) => _complete(cart, input),
                  );
                },
              )),
            ),
          ]),
        ),
      ),
    );
  }
}
