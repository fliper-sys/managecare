import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../core/theme/text_styles.dart';

class DrinkOrdersHistoryScreen extends StatelessWidget {
  const DrinkOrdersHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DrinkProvider>(context);
    final paidOrders = provider.orders
        .where((o) => o.status == 'paid' || o.status == 'completed')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Orders History')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: paidOrders.isEmpty
            ? const Center(child: Text('No paid orders yet'))
            : ListView.separated(
                itemCount: paidOrders.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final o = paidOrders[idx];
                  return ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text('Order #${o.id}', style: AppTextStyles.subtitle1),
                    subtitle: Text(
                        'Items: ${o.lines.length} • Total: \u20a6${o.total().toStringAsFixed(2)}'),
                    trailing: Text(o.createdAt.toLocal().toString().split('.').first),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #${o.id}', style: AppTextStyles.heading5),
                            const SizedBox(height: 8),
                            ...o.lines.map((l) {
                              final drink = provider.getDrinkById(l.drinkId);
                              return ListTile(
                                leading: drink?.imageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(drink!.imageUrl!, width: 40, height: 40, fit: BoxFit.cover),
                                      )
                                    : Text(drink?.emoji ?? '🍹', style: const TextStyle(fontSize: 24)),
                                title: Text(drink?.name ?? 'Unknown'),
                                subtitle: Text('${l.quantityBottles} bottles'),
                                trailing: Text('\u20a6${l.lineTotal().toStringAsFixed(2)}'),
                              );
                            }),
                            const SizedBox(height: 8),
                            Text('Status: ${o.status}'),
                            const SizedBox(height: 8),
                            Text('Created: ${o.createdAt}'),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(child: const Text('Close'), onPressed: () => Navigator.pop(context)),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
