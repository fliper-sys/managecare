import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';

class PharmacyCartSheet extends StatefulWidget {
  final Map<String, int> cart;
  const PharmacyCartSheet({required this.cart, super.key});

  @override
  State<PharmacyCartSheet> createState() => _PharmacyCartSheetState();
}

class _PharmacyCartSheetState extends State<PharmacyCartSheet> {
  late Map<String, int> _items;

  // Editable tax (%) and discount
  double _taxPercent = 0.0;
  double _discountAmount = 0.0;
  late TextEditingController _taxCtrl;
  late TextEditingController _discountCtrl;

  // Per-item override prices
  final Map<String, double> _overridePrices = {};

  @override
  void initState() {
    super.initState();
    _items = Map.from(widget.cart);
    _taxCtrl = TextEditingController(text: _taxPercent.toStringAsFixed(2));
    _discountCtrl = TextEditingController(text: _discountAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _taxCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  void _changeQty(String id, int delta) {
    setState(() {
      final cur = _items[id] ?? 0;
      final next = (cur + delta).clamp(0, 999);
      if (next <= 0) {
        _items.remove(id);
      } else {
        _items[id] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PharmacyProvider>(context, listen: false);
    final list = _items.entries.toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cart', style: AppTextStyles.heading5),
            const SizedBox(height: 8),
            if (list.isEmpty) ...[
              const Text('Cart is empty', style: AppTextStyles.body2),
            ] else ...[
              ...list.map((e) {
                final drug = provider.drugs.firstWhere((d) => d.id == e.key,
                    orElse: () => provider.drugs.first);
                final price = _overridePrices[e.key] ?? drug.price;
                return ListTile(
                  title: Text(drug.name, style: AppTextStyles.body2),
                  subtitle: Row(children: [
                    Text('Stock: ${drug.stock} • ${formatCurrency(price)} each'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () async {
                        final ctrl = TextEditingController(text: price.toStringAsFixed(2));
                        final res = await showDialog<double>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Edit selling price'),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Price'),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(context).pop(double.tryParse(ctrl.text) ?? price), child: const Text('Save')),
                            ],
                          ),
                        );
                        if (res != null) setState(() => _overridePrices[e.key] = res);
                      },
                    ),
                  ]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          onPressed: () => _changeQty(e.key, -1),
                          icon: const Icon(Icons.remove)),
                      Text('${e.value}', style: AppTextStyles.body2),
                      IconButton(
                          onPressed: () => _changeQty(e.key, 1),
                          icon: const Icon(Icons.add)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              // Editable Tax & Discount
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tax (%)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _taxPercent = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Discount',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _discountAmount = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Total with tax/discount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: AppTextStyles.heading5),
                  Builder(builder: (_) {
                    double subtotal = 0.0;
                    for (final e in _items.entries) {
                      final drug = provider.drugs.firstWhere((d) => d.id == e.key);
                      final price = _overridePrices[e.key] ?? drug.price;
                      subtotal += price * e.value;
                    }
                    final taxAmount = subtotal * (_taxPercent / 100.0);
                    final totalWithExtras = subtotal + taxAmount - _discountAmount;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Subtotal: ${formatCurrency(subtotal)}', style: AppTextStyles.caption),
                        Text('Tax: ${formatCurrency(taxAmount)}', style: AppTextStyles.caption),
                        Text('Discount: -${formatCurrency(_discountAmount)}', style: AppTextStyles.caption.copyWith(color: Colors.red)),
                        const SizedBox(height: 4),
                        Text(formatCurrency(totalWithExtras), style: AppTextStyles.heading5),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // perform sale: create prescription and reduce stock via provider
                        double subtotal = 0.0;
                        final items = _items.entries
                            .map((e) {
                              final drug = provider.drugs.firstWhere((d) => d.id == e.key);
                              final price = _overridePrices[e.key] ?? drug.price;
                              subtotal += price * e.value;
                              return {'drugId': e.key, 'qty': e.value, 'price': price, 'name': drug.name};
                            })
                            .toList();
                        final taxAmount = subtotal * (_taxPercent / 100.0);
                        final totalWithExtras = subtotal + taxAmount - _discountAmount;

                        await provider.addPrescription('WALKIN', items.map((i) => {'drugId': i['drugId'], 'qty': i['qty']}).toList(),
                            persist: provider.hasRemote, userId: 'pos');
                        // reduce stock locally and optionally persist per provider
                        for (final e in _items.entries) {
                          final drug =
                              provider.drugs.firstWhere((d) => d.id == e.key);
                          final newStock =
                              (drug.stock - e.value).clamp(0, 999999);
                          await provider.updateDrugStock(e.key, newStock,
                              persist: provider.hasRemote);
                        }
                        if (!mounted) return;
                        Navigator.of(context).pop({
                          'items': items,
                          'subtotal': subtotal,
                          'taxPercent': _taxPercent,
                          'taxAmount': taxAmount,
                          'discountAmount': _discountAmount,
                          'total': totalWithExtras,
                          'paymentMethod': 'Cash',
                        });
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: const Text('Confirm Sale'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

