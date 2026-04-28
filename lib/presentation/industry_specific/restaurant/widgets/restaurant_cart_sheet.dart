import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/receipt_manager.dart';
import '../providers/restaurant_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/async_button.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/worker_permissions.dart';

class RestaurantCartSheet extends StatefulWidget {
  final Map<String, int> cart;
  const RestaurantCartSheet({required this.cart, super.key});

  @override
  State<RestaurantCartSheet> createState() => _RestaurantCartSheetState();
}

class _RestaurantCartSheetState extends State<RestaurantCartSheet> {
  late Map<String, int> _items;
  String? _selectedTable;

  // Editable tax (%) and discount (absolute amount)
  double _taxPercent = 0.0;
  double _discountAmount = 0.0;
  late TextEditingController _taxCtrl;
  late TextEditingController _discountCtrl;

  // Per-item override prices (selling price editable in cart)
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
    final provider = Provider.of<RestaurantProvider>(context, listen: false);
    final list = _items.entries.toList();



    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Order Cart', style: AppTextStyles.heading5),
            const SizedBox(height: 12),
            // Table selection
            DropdownButton<String>(
              value: _selectedTable,
              hint: const Text('Select Table'),
              items: [
                'Table 1',
                'Table 2',
                'Table 3',
                'Table 4',
                'Table 5',
                'Bar',
                'Takeout'
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedTable = val),
            ),
            const SizedBox(height: 12),
            // Cart items
            if (list.isEmpty) ...[
              const Text('Cart is empty', style: AppTextStyles.body2),
            ] else ...[
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, idx) {
                    final e = list[idx];
                    final matches =
                        provider.menuItems.where((m) => m.id == e.key).toList();
                    if (matches.isEmpty) return const SizedBox.shrink();
                    final item = matches.first;
                    final price = _overridePrices[e.key] ?? item.price;
                    return Card(
                      child: ListTile(
                        title: Text(item.name, style: AppTextStyles.body2),
                        subtitle: Row(children: [
                          Text('${formatCurrency(price)} each'),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () async {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              if (!auth.isOwnerUser) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Only business owners can edit prices'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              // Existing edit price logic
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
                                icon: const Icon(Icons.remove, size: 20)),
                            Text('${e.value}', style: AppTextStyles.body2),
                            IconButton(
                                onPressed: () => _changeQty(e.key, 1),
                                icon: const Icon(Icons.add, size: 20)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
                    // Editable Tax & Discount
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taxCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tax (%)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _taxPercent = double.tryParse(v) ?? 0.0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final canApplyDiscount = auth.isOwnerUser || WorkerPermissions.canApplyDiscount(auth.currentUser?.role ?? '');
                      return TextField(
                        controller: _discountCtrl,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Discount',
                          border: const OutlineInputBorder(),
                          enabled: canApplyDiscount,
                          hintText: canApplyDiscount ? null : 'Only owner/manager can apply discounts',
                        ),
                        enabled: canApplyDiscount,
                        onChanged: canApplyDiscount ? (v) => setState(() => _discountAmount = double.tryParse(v) ?? 0.0) : null,
                      );
                    },
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
                  for (final e in list) {
                    final matches = provider.menuItems.where((m) => m.id == e.key).toList();
                    if (matches.isNotEmpty) {
                      final item = matches.first;
                      final price = _overridePrices[e.key] ?? item.price;
                      subtotal += price * e.value;
                    }
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
            const SizedBox(height: 12),
            // Checkout button
            Row(
              children: [
                Expanded(
                  child: AsyncButton(
                    buttonKey: const Key('confirm-order-button'),
                    onPressed: list.isNotEmpty && _selectedTable != null
                        ? () async {
                            // Prepare sale map before checkout
                            double subtotal = 0.0;
                            for (final e in list) {
                              final matches = provider.menuItems.where((m) => m.id == e.key).toList();
                              final item = matches.isNotEmpty ? matches.first : null;
                              subtotal += (item?.price ?? 0.0) * e.value;
                            }
                            final taxAmount = subtotal * (_taxPercent / 100.0);
                            final totalWithExtras = subtotal + taxAmount - _discountAmount;

                            final saleMap = {
                              'id':
                                  'ORD-${DateTime.now().millisecondsSinceEpoch}',
                              'items': list.map((e) {
                                final matches = provider.menuItems
                                    .where((m) => m.id == e.key)
                                    .toList();
                                final item =
                                    matches.isNotEmpty ? matches.first : null;
                                final price = _overridePrices[e.key] ?? (item?.price ?? 0.0);
                                return {
                                  'name': item?.name ?? e.key,
                                  'quantity': e.value,
                                  'price': price,
                                };
                              }).toList(),
                              'subtotal': subtotal,
                              'taxPercent': _taxPercent,
                              'taxAmount': taxAmount,
                              'discountAmount': _discountAmount,
                              'total': totalWithExtras,
                              'paymentMethod': 'Cash',
                              'table': _selectedTable,
                            };

                            // Create order with table and cart items
                            if (mounted) {
                              Navigator.of(context).pop(saleMap);
                            }

                            // Post-sale receipt actions
                            try {
                              await ReceiptManager.handlePostSale(
                                  context, saleMap);
                            } catch (_) {}
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: const Text('Confirm Order'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

