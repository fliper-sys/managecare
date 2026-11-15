import 'package:flutter/material.dart';

import '../../business_profiles/business_profile.dart';
import '../../design/app_tokens.dart';
import '../../design/app_type.dart';
import '../../design/components/components.dart';
import '../../design/format.dart';
import 'cart_models.dart';

/// Catalogue and cart screen body shared by the catalogue-and-cart family.
/// Words come from [terms], colour from [accent]; it reads no provider.
class CatalogueCartView extends StatefulWidget {
  const CatalogueCartView({
    super.key,
    required this.items,
    required this.cart,
    required this.terms,
    required this.accent,
    required this.onCheckout,
    this.isLoading = false,
    this.onOutOfStock,
  });

  final List<CatalogueItem> items;
  final CartState cart;
  final Terms terms;
  final Color accent;
  final VoidCallback onCheckout;
  final bool isLoading;

  /// Called when the user taps an item with no stock left to add.
  final ValueChanged<CatalogueItem>? onOutOfStock;

  @override
  State<CatalogueCartView> createState() => _CatalogueCartViewState();
}

class _CatalogueCartViewState extends State<CatalogueCartView> {
  String _query = '';
  String? _category;

  List<String> get _categories {
    final set = <String>{for (final i in widget.items) if (i.category.isNotEmpty) i.category};
    return set.toList()..sort();
  }

  List<CatalogueItem> get _visible {
    final q = _query.trim().toLowerCase();
    return [
      for (final i in widget.items)
        if ((_category == null || i.category == _category) && (q.isEmpty || i.name.toLowerCase().contains(q))) i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final visible = _visible;
    final cats = _categories;

    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, AppTokens.s8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: AppType.sans(size: 15, color: t.ink),
            decoration: InputDecoration(
              hintText: 'Search ${widget.terms.items.toLowerCase()}',
              hintStyle: AppType.sans(size: 15, color: t.inkFaint),
              prefixIcon: Icon(Icons.search_rounded, color: t.inkMuted),
              filled: true,
              fillColor: t.raised,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.rControl),
                borderSide: BorderSide(color: t.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.rControl),
                borderSide: BorderSide(color: t.line),
              ),
            ),
          ),
        ),
        if (cats.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
              children: [
                _CatChip(label: 'All', selected: _category == null, accent: widget.accent, onTap: () => setState(() => _category = null)),
                for (final c in cats)
                  _CatChip(label: c, selected: _category == c, accent: widget.accent, onTap: () => setState(() => _category = c)),
              ],
            ),
          ),
        Expanded(child: _body(context, visible)),
      ]),
      Positioned(
        left: AppTokens.s16,
        right: AppTokens.s16,
        bottom: AppTokens.s16,
        child: ListenableBuilder(
          listenable: widget.cart,
          builder: (context, _) => widget.cart.isEmpty
              ? const SizedBox.shrink()
              : _CartBar(cart: widget.cart, accent: widget.accent, terms: widget.terms, onTap: widget.onCheckout),
        ),
      ),
    ]);
  }

  Widget _body(BuildContext context, List<CatalogueItem> visible) {
    final t = AppTokens.of(context);
    if (widget.isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppTokens.s16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s8),
        itemBuilder: (_, __) => const SkeletonBlock(height: 68, radius: AppTokens.rRow),
      );
    }
    if (widget.items.isEmpty) {
      return _Empty(title: 'No ${widget.terms.items.toLowerCase()} yet', body: 'Add your first ${widget.terms.item.toLowerCase()} to start selling.');
    }
    if (visible.isEmpty) {
      return _Empty(title: 'Nothing matches', body: 'Try another search or category.');
    }
    return ListenableBuilder(
      listenable: widget.cart,
      builder: (context, _) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s8, AppTokens.s16, 112),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s8),
        itemBuilder: (context, i) {
          final item = visible[i];
          return _ItemRow(
            item: item,
            qty: widget.cart.qtyOf(item.id),
            accent: widget.accent,
            onAdd: () {
              if (!widget.cart.add(item)) widget.onOutOfStock?.call(item);
            },
            onMinus: () => widget.cart.decrement(item.id),
            muted: t.inkMuted,
          );
        },
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.qty, required this.accent, required this.onAdd, required this.onMinus, required this.muted});
  final CatalogueItem item;
  final int qty;
  final Color accent;
  final VoidCallback onAdd;
  final VoidCallback onMinus;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final soldOut = item.stock <= 0;
    final low = !soldOut && item.stock < 10;
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12, vertical: AppTokens.s8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppTokens.rRow),
        border: Border.all(color: qty > 0 ? accent : t.line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.sans(size: 15, weight: FontWeight.w700, color: t.ink)),
            const SizedBox(height: 2),
            Row(children: [
              Text(formatNaira(item.price), style: AppType.mono(size: 13, color: t.inkMuted)),
              const SizedBox(width: AppTokens.s8),
              if (soldOut) const StatusChip(label: 'Sold out', tone: StatusTone.danger),
              if (low) StatusChip(label: '${item.stock.toStringAsFixed(0)} left', tone: StatusTone.warning),
            ]),
          ]),
        ),
        if (qty == 0)
          _RoundBtn(icon: Icons.add_rounded, label: 'Add ${item.name}', onTap: soldOut ? null : onAdd, accent: accent, filled: true)
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            _RoundBtn(icon: Icons.remove_rounded, label: 'Remove one ${item.name}', onTap: onMinus, accent: accent, filled: false),
            SizedBox(width: 32, child: Text('$qty', textAlign: TextAlign.center, style: AppType.mono(size: 16, weight: FontWeight.w700, color: t.ink))),
            _RoundBtn(icon: Icons.add_rounded, label: 'Add one more ${item.name}', onTap: onAdd, accent: accent, filled: true),
          ]),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.label, required this.onTap, required this.accent, required this.filled});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TactilePressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.rControl),
            border: Border.all(color: filled ? accent : t.line),
          ),
          child: Icon(icon, size: 22, color: filled ? t.onAccent : t.ink),
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.selected, required this.accent, required this.onTap});
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppTokens.s8),
      child: TactilePressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTokens.tint(accent) : t.raised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? accent : t.line),
          ),
          child: Text(label, style: AppType.sans(size: 13, weight: FontWeight.w700, color: selected ? t.ink : t.inkMuted)),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.cart, required this.accent, required this.terms, required this.onTap});
  final CartState cart;
  final Color accent;
  final Terms terms;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TactilePressable(
      onTap: onTap,
      semanticLabel: 'Review ${cart.count} items, ${formatNaira(cart.total)}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppTokens.rCard), boxShadow: t.cardShadow),
        child: Row(children: [
          Text('${cart.count} ${cart.count == 1 ? terms.item.toLowerCase() : terms.items.toLowerCase()}',
              style: AppType.sans(size: 14, weight: FontWeight.w700, color: t.onAccent)),
          const Spacer(),
          Text(formatNaira(cart.total), style: AppType.mono(size: 17, weight: FontWeight.w700, color: t.onAccent)),
          const SizedBox(width: AppTokens.s8),
          Icon(Icons.arrow_forward_rounded, size: 20, color: t.onAccent),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: AppType.sans(size: 16, weight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: AppTokens.s8),
          Text(body, textAlign: TextAlign.center, style: AppType.sans(size: 13, color: t.inkMuted)),
        ]),
      ),
    );
  }
}
