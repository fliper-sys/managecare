import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../business_profiles/business_profile.dart';
import '../../design/app_tokens.dart';
import '../../design/app_type.dart';
import '../../design/components/components.dart';
import '../../design/format.dart';
import '../../design/motion.dart';
import '../../design/naira_input_formatter.dart';
import 'cart_models.dart';
import 'price_editor.dart';
import 'receipt_card.dart';

/// Records the sale and returns the receipt, or throws.
typedef CompleteSale = Future<SaleReceipt> Function(CheckoutInput input);

/// The one checkout sheet for the catalogue-and-cart family. Replaces the
/// three separate checkout sheets in the old retail, bakery and drink flows.
Future<void> showCheckoutSheet(
  BuildContext context, {
  required CartState cart,
  required Terms terms,
  required Color accent,
  required CompleteSale onComplete,
  List<PayMethod> methods = const [PayMethod.cash, PayMethod.transfer, PayMethod.card, PayMethod.credit],
  List<StoreOption> stores = const [],
  String? initialStoreId,
  bool allowSplit = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CheckoutSheet(
      cart: cart,
      terms: terms,
      accent: accent,
      onComplete: onComplete,
      methods: methods,
      stores: stores,
      initialStoreId: initialStoreId,
      allowSplit: allowSplit,
    ),
  );
}

enum _Phase { review, processing, done, failed }

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({
    super.key,
    required this.cart,
    required this.terms,
    required this.accent,
    required this.onComplete,
    this.methods = const [PayMethod.cash, PayMethod.transfer, PayMethod.card, PayMethod.credit],
    this.stores = const [],
    this.initialStoreId,
    this.allowSplit = true,
  });

  final CartState cart;
  final Terms terms;
  final Color accent;
  final CompleteSale onComplete;
  final List<PayMethod> methods;
  final List<StoreOption> stores;
  final String? initialStoreId;
  final bool allowSplit;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  _Phase _phase = _Phase.review;
  late PayMethod _method = widget.methods.first;
  bool _split = false;
  late String? _storeId = widget.initialStoreId ?? (widget.stores.isEmpty ? null : widget.stores.first.id);
  SaleReceipt? _receipt;
  final _customer = TextEditingController();
  final _discount = TextEditingController();
  final _cash = TextEditingController();
  final _card = TextEditingController();
  final _transfer = TextEditingController();

  static const _splitMethods = [PayMethod.cash, PayMethod.card, PayMethod.transfer];

  @override
  void dispose() {
    for (final c in [_customer, _discount, _cash, _card, _transfer]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => parseNaira(c.text) ?? 0;

  List<PaymentSplit> get _splits => [
        PaymentSplit(PayMethod.cash, _num(_cash)),
        PaymentSplit(PayMethod.card, _num(_card)),
        PaymentSplit(PayMethod.transfer, _num(_transfer)),
      ].where((s) => s.amount > 0).toList();

  double get _splitSum => _splits.fold(0.0, (a, s) => a + s.amount);

  /// A split must add up to the total, to the nearest naira.
  bool get _splitOk => (_splitSum - widget.cart.total).abs() < 1;

  bool get _canSubmit => _phase != _Phase.processing && !widget.cart.isEmpty && (!_split || _splitOk);

  Future<void> _submit() async {
    if (!_canSubmit) return; // also blocks a double submit
    setState(() => _phase = _Phase.processing);
    try {
      final name = _customer.text.trim();
      final r = await widget.onComplete(CheckoutInput(
        method: _split ? null : _method,
        customer: name.isEmpty ? null : name,
        splits: _split ? _splits : const [],
        storeId: _storeId,
      ));
      widget.cart.clear();
      if (!mounted) return;
      setState(() {
        _receipt = r;
        _phase = _Phase.done;
      });
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _editPrice(CartLine l) => showPriceEditor(context, widget.cart, l);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return PopScope(
      canPop: _phase != _Phase.processing,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTokens.rSheet)),
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.s16),
              child: AnimatedSwitcher(
                duration: Motion.scaled(context, Motion.enter),
                child: KeyedSubtree(key: ValueKey(_phase == _Phase.done), child: _content(t)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(AppTokens t, String label, bool on, VoidCallback? tap) => TactilePressable(
        onTap: tap,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppTokens.tint(widget.accent) : t.raised,
            borderRadius: BorderRadius.circular(AppTokens.rControl),
            border: Border.all(color: on ? widget.accent : t.line),
          ),
          child: Text(label, style: AppType.sans(size: 13, weight: FontWeight.w700, color: on ? t.ink : t.inkMuted)),
        ),
      );

  Widget _amountField(AppTokens t, String label, TextEditingController c, bool busy) => Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.s8),
        child: TextField(
          controller: c,
          enabled: !busy,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [NairaInputFormatter()],
          style: AppType.mono(size: 14, color: t.ink),
          decoration: InputDecoration(
            labelText: label,
            prefixText: '₦ ',
            filled: true,
            fillColor: t.raised,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rControl), borderSide: BorderSide(color: t.line)),
          ),
        ),
      );

  Widget _content(AppTokens t) {
    if (_phase == _Phase.done && _receipt != null) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ReceiptCard(receipt: _receipt!, title: widget.terms.doneTitle, accent: widget.accent),
        if (_receipt!.queuedOffline) ...[
          const SizedBox(height: AppTokens.s12),
          Container(
            padding: const EdgeInsets.all(AppTokens.s12),
            decoration: BoxDecoration(color: t.warningBg, borderRadius: BorderRadius.circular(AppTokens.rControl)),
            child: Text('Saved on this device. It uploads when you are back online.',
                style: AppType.sans(size: 13, weight: FontWeight.w600, color: t.warning)),
          ),
        ],
        const SizedBox(height: AppTokens.s16),
        _Primary(label: widget.terms.newSale, accent: widget.accent, onTap: () => Navigator.of(context).pop()),
      ]);
    }
    final busy = _phase == _Phase.processing;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Review ${widget.terms.sale.toLowerCase()}', style: AppType.sans(size: 18, weight: FontWeight.w800, color: t.ink)),
      Text('Tap a line to change its price', style: AppType.sans(size: 12, color: t.inkMuted)),
      const SizedBox(height: AppTokens.s12),
      ListenableBuilder(
        listenable: widget.cart,
        builder: (_, __) => Column(children: [
          for (final l in widget.cart.lines)
            TactilePressable(
              onTap: busy ? null : () => _editPrice(l),
              semanticLabel: 'Edit price of ${l.item.name}',
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${l.qty} × ${l.item.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 14, color: t.ink)),
                      if (l.overridden || l.mode == PriceMode.wholesale)
                        Text(l.overridden ? 'Custom price ${formatNairaPrecise(l.unitPrice)}' : 'Wholesale ${formatNairaPrecise(l.unitPrice)}',
                            style: AppType.sans(size: 11, color: l.overridden ? t.warning : t.inkMuted)),
                    ]),
                  ),
                  Text(formatNairaPrecise(l.total), style: AppType.mono(size: 14, color: t.ink)),
                  const SizedBox(width: AppTokens.s8),
                  Icon(Icons.edit_outlined, size: 18, color: l.overridden ? t.warning : t.inkMuted),
                ]),
              ),
            ),
          Divider(color: t.line),
          _line(t, 'Subtotal', formatNairaPrecise(widget.cart.subtotal)),
          if (widget.cart.taxPercent > 0) _line(t, 'Tax ${widget.cart.taxPercent.toStringAsFixed(widget.cart.taxPercent % 1 == 0 ? 0 : 1)}%', formatNairaPrecise(widget.cart.taxAmount)),
          if (widget.cart.discount > 0) _line(t, 'Discount', '-${formatNairaPrecise(widget.cart.discount)}'),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text('Total', style: AppType.sans(size: 15, weight: FontWeight.w700, color: t.ink))),
            Text(formatNairaPrecise(widget.cart.total), style: AppType.mono(size: 22, weight: FontWeight.w700, color: t.ink)),
          ]),
        ]),
      ),
      const SizedBox(height: AppTokens.s16),
      TextField(
        controller: _discount,
        enabled: !busy,
        onChanged: (v) => widget.cart.setDiscount(parseNaira(v) ?? 0),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [NairaInputFormatter()],
        style: AppType.mono(size: 14, color: t.ink),
        decoration: InputDecoration(
          labelText: 'Discount (optional)',
          prefixText: '₦ ',
          filled: true,
          fillColor: t.raised,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rControl), borderSide: BorderSide(color: t.line)),
        ),
      ),
      if (widget.stores.length > 1) ...[
        const SizedBox(height: AppTokens.s12),
        Wrap(spacing: AppTokens.s8, runSpacing: AppTokens.s8, children: [
          for (final s in widget.stores) _chip(t, s.name, s.id == _storeId, busy ? null : () => setState(() => _storeId = s.id)),
        ]),
      ],
      const SizedBox(height: AppTokens.s12),
      Wrap(spacing: AppTokens.s8, runSpacing: AppTokens.s8, children: [
        for (final m in widget.methods) _chip(t, m.label, !_split && m == _method, busy ? null : () => setState(() { _split = false; _method = m; })),
        if (widget.allowSplit) _chip(t, 'Split', _split, busy ? null : () => setState(() => _split = true)),
      ]),
      if (_split) ...[
        const SizedBox(height: AppTokens.s12),
        _amountField(t, 'Cash', _cash, busy),
        _amountField(t, 'Card', _card, busy),
        _amountField(t, 'Transfer', _transfer, busy),
        Text(
          _splitOk ? 'Adds up to the total.' : 'Short by ${formatNairaPrecise((widget.cart.total - _splitSum).abs())}${_splitSum > widget.cart.total ? ' (too much)' : ''}',
          style: AppType.sans(size: 12, weight: FontWeight.w600, color: _splitOk ? t.success : t.warning),
        ),
      ],
      const SizedBox(height: AppTokens.s12),
      TextField(
        controller: _customer,
        enabled: !busy,
        style: AppType.sans(size: 14, color: t.ink),
        decoration: InputDecoration(
          hintText: '${widget.terms.customer} (optional), default ${widget.terms.walkIn}',
          hintStyle: AppType.sans(size: 14, color: t.inkFaint),
          filled: true,
          fillColor: t.raised,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rControl), borderSide: BorderSide(color: t.line)),
        ),
      ),
      if (_phase == _Phase.failed) ...[
        const SizedBox(height: AppTokens.s12),
        Container(
          padding: const EdgeInsets.all(AppTokens.s12),
          decoration: BoxDecoration(color: t.dangerBg, borderRadius: BorderRadius.circular(AppTokens.rControl)),
          child: Text('Could not record the ${widget.terms.sale.toLowerCase()}. Nothing was charged. Try again.',
              style: AppType.sans(size: 13, weight: FontWeight.w600, color: t.danger)),
        ),
      ],
      const SizedBox(height: AppTokens.s16),
      _Primary(
        label: busy ? 'Recording…' : (_phase == _Phase.failed ? 'Try again' : widget.terms.completeCta),
        accent: widget.accent,
        onTap: _canSubmit ? _submit : null,
      ),
    ]);
  }

  Widget _line(AppTokens t, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(k, style: AppType.sans(size: 13, color: t.inkMuted))),
          Text(v, style: AppType.mono(size: 13, color: t.inkMuted)),
        ]),
      );
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, required this.accent, required this.onTap});
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TactilePressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppTokens.rControl)),
          child: Text(label, style: AppType.sans(size: 15, weight: FontWeight.w800, color: t.onAccent)),
        ),
      ),
    );
  }
}
