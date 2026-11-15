import 'package:flutter/material.dart';

import '../../design/format.dart';
import '../../design/naira_input_formatter.dart';
import 'cart_models.dart';

/// Lets the cashier change one line's unit price. Typing groups thousands as
/// they go (45,000 or 1,250.50). "Use list price" removes a custom price.
/// Used from both the catalogue and the checkout sheet.
Future<void> showPriceEditor(BuildContext context, CartState cart, CartLine line) async {
  final list = (line.mode == PriceMode.wholesale && line.item.hasWholesale) ? line.item.wholesalePrice! : line.item.price;
  final seed = line.unitPrice.toStringAsFixed(line.unitPrice % 1 == 0 ? 0 : 2);
  final c = TextEditingController(
    text: const NairaInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: seed)).text,
  );
  // -1 means reset to list price, null means cancelled.
  final result = await showDialog<double?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Price for ${line.item.name}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('List price ${formatNairaPrecise(list)}'),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [NairaInputFormatter()],
          decoration: const InputDecoration(prefixText: '₦ '),
          onSubmitted: (_) => Navigator.pop(ctx, parseNaira(c.text)),
        ),
      ]),
      actions: [
        if (line.overridden) TextButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('Use list price')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, parseNaira(c.text)), child: const Text('Save')),
      ],
    ),
  );
  c.dispose();
  if (result == null) return;
  cart.setOverride(line.item.id, result < 0 ? null : result);
}
