import 'package:flutter/material.dart';

import '../../business_profiles/business_profile.dart';
import '../../design/app_tokens.dart';
import '../../design/app_type.dart';
import '../../design/components/components.dart';
import '../../design/format.dart';
import '../../design/motion.dart';
import 'cart_models.dart';
import 'receipt_card.dart';

/// Records the sale and returns the receipt, or throws.
typedef CompleteSale = Future<SaleReceipt> Function(PayMethod method, String? customer);

/// The one checkout sheet for the catalogue-and-cart family. Replaces the
/// three separate checkout sheets in the old retail, bakery and drink flows.
Future<void> showCheckoutSheet(
  BuildContext context, {
  required CartState cart,
  required Terms terms,
  required Color accent,
  required CompleteSale onComplete,
  List<PayMethod> methods = PayMethod.values,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CheckoutSheet(cart: cart, terms: terms, accent: accent, onComplete: onComplete, methods: methods),
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
    this.methods = PayMethod.values,
  });

  final CartState cart;
  final Terms terms;
  final Color accent;
  final CompleteSale onComplete;
  final List<PayMethod> methods;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  _Phase _phase = _Phase.review;
  late PayMethod _method = widget.methods.first;
  SaleReceipt? _receipt;
  final _customer = TextEditingController();

  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phase == _Phase.processing || widget.cart.isEmpty) return; // no double submit
    setState(() => _phase = _Phase.processing);
    try {
      final name = _customer.text.trim();
      final r = await widget.onComplete(_method, name.isEmpty ? null : name);
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

  Widget _content(AppTokens t) {
    if (_phase == _Phase.done && _receipt != null) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ReceiptCard(receipt: _receipt!, title: widget.terms.doneTitle, accent: widget.accent),
        const SizedBox(height: AppTokens.s16),
        _Primary(label: widget.terms.newSale, accent: widget.accent, onTap: () => Navigator.of(context).pop()),
      ]);
    }
    final busy = _phase == _Phase.processing;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Review ${widget.terms.sale.toLowerCase()}', style: AppType.sans(size: 18, weight: FontWeight.w800, color: t.ink)),
      const SizedBox(height: AppTokens.s12),
      ListenableBuilder(
        listenable: widget.cart,
        builder: (_, __) => Column(children: [
          for (final l in widget.cart.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('${l.qty} × ${l.item.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 14, color: t.ink))),
                Text(formatNaira(l.total), style: AppType.mono(size: 14, color: t.ink)),
              ]),
            ),
          Divider(color: t.line),
          Row(children: [
            Expanded(child: Text('Total', style: AppType.sans(size: 15, weight: FontWeight.w700, color: t.ink))),
            Text(formatNaira(widget.cart.total), style: AppType.mono(size: 22, weight: FontWeight.w700, color: t.ink)),
          ]),
        ]),
      ),
      const SizedBox(height: AppTokens.s16),
      Wrap(spacing: AppTokens.s8, runSpacing: AppTokens.s8, children: [
        for (final m in widget.methods)
          TactilePressable(
            onTap: busy ? null : () => setState(() => _method = m),
            semanticLabel: m.label,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: m == _method ? AppTokens.tint(widget.accent) : t.raised,
                borderRadius: BorderRadius.circular(AppTokens.rControl),
                border: Border.all(color: m == _method ? widget.accent : t.line),
              ),
              child: Text(m.label, style: AppType.sans(size: 13, weight: FontWeight.w700, color: m == _method ? t.ink : t.inkMuted)),
            ),
          ),
      ]),
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
        onTap: busy ? null : _submit,
      ),
    ]);
  }
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
