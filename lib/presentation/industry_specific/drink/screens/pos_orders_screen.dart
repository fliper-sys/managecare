import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../services/email_service.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/utils/currency.dart';

class POSOrdersScreen extends StatefulWidget {
  const POSOrdersScreen({super.key});

  @override
  State<POSOrdersScreen> createState() => _POSOrdersScreenState();
}

class _POSOrdersScreenState extends State<POSOrdersScreen> {
  String? selectedDrinkId;
  int quantity = 1;
  List<Modifier> selectedModifiers = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DrinkProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS / Orders'),
        backgroundColor: Colors.brown,
        actions: [
          IconButton(
            tooltip: 'Orders history',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, Routes.drinkOrdersHistory),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Add Drink',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search drinks...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.separated(
                  itemCount: provider.drinks
                      .where((d) => d.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final results = provider.drinks
                        .where((d) => d.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();
                    final drink = results[i];
                    return ListTile(
                      leading: drink.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(drink.imageUrl!,
                                  width: 40, height: 40, fit: BoxFit.cover),
                            )
                          : Text(drink.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(drink.name),
                      subtitle: Text('\u20a6${drink.pricePerBottle.toStringAsFixed(2)}'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedDrinkId = drink.id;
                            quantity = 1;
                            selectedModifiers = [];
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        child: const Text('Add'),
                      ),
                    );
                  },
                ),
              )
            else
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.drinks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final drink = provider.drinks[idx];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDrinkId = drink.id;
                          quantity = 1;
                          selectedModifiers = [];
                        });
                      },
                      child: Container(
                        width: 70,
                        decoration: BoxDecoration(
                          color: selectedDrinkId == drink.id
                              ? Colors.brown.shade100
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.brown.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            drink.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(drink.imageUrl!,
                                        width: 36, height: 36, fit: BoxFit.cover),
                                  )
                                : Text(drink.emoji,
                                    style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(drink.name,
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            if (selectedDrinkId != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Details',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Quantity:'),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: quantity > 1
                                ? () => setState(() => quantity--)
                                : null,
                          ),
                          Text('$quantity'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setState(() => quantity++),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Modifiers:'),
                      Wrap(
                        spacing: 8,
                        children: provider.modifiers.map((mod) {
                          final selected = selectedModifiers.contains(mod);
                          return FilterChip(
                            label: Text(mod.name),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  selectedModifiers.add(mod);
                                } else {
                                  selectedModifiers.remove(mod);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add Order'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown),
                        onPressed: () async {
                          final drink = provider.getDrinkById(selectedDrinkId!);
                          if (drink == null) return;
                          provider.createOrder(Order(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            lines: [
                              OrderLine(
                                drinkId: drink.id,
                                quantityBottles: quantity,
                                modifiers: List.from(selectedModifiers),
                                unitPrice: drink.pricePerBottle,
                              )
                            ],
                          ));
                          // After creating order, if some items fell below threshold notify admins on Pro plans
                          try {
                            final businessProvider =
                                Provider.of<BusinessProvider>(context,
                                    listen: false);
                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            final canSendLowStockAlert =
                                businessProvider.hasFeatureAccess(
                              'email_receipts',
                            );
                            final bType = businessProvider
                                    .currentBusiness?.businessType ??
                                '';
                            if (canSendLowStockAlert &&
                                (bType == 'drink' || bType == 'auto')) {
                              final low = provider.getLowStockDrinks();
                              if (low.isNotEmpty) {
                                final userEmail =
                                    authProvider.currentUser?.email;
                                if (userEmail != null && userEmail.isNotEmpty) {
                                  await EmailService()
                                      .sendLowStockAlert(userEmail, {
                                    'businessName':
                                        businessProvider.currentBusiness?.id ??
                                            'Business',
                                    'itemsCount': low.length.toString(),
                                  });
                                }
                              }
                            }
                          } catch (_) {}
                          setState(() {
                            selectedDrinkId = null;
                            quantity = 1;
                            selectedModifiers = [];
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('Open Orders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: provider.getOpenOrders().length,
                itemBuilder: (context, idx) {
                  final order = provider.getOpenOrders()[idx];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text('Order #${order.id}'),
                      subtitle: Text('Total: ${formatCurrency(order.total())}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) async {
                          if (status == 'paid') {
                            // Ask for payment method before processing paid order
                            final paymentMethod = await showModalBottomSheet<String>(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: const Text('Cash'),
                                      onTap: () => Navigator.pop(ctx, 'Cash'),
                                    ),
                                    ListTile(
                                      title: const Text('Debit/Credit Card'),
                                      onTap: () => Navigator.pop(ctx, 'Debit/Credit Card'),
                                    ),
                                    ListTile(
                                      title: const Text('Digital Wallet'),
                                      onTap: () => Navigator.pop(ctx, 'Digital Wallet'),
                                    ),
                                    ListTile(
                                      title: const Text('Cancel'),
                                      onTap: () => Navigator.pop(ctx, null),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (paymentMethod == null) return; // cancelled

                            try {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              await provider.processPaidOrder(
                                order.id,
                                paymentMethod,
                                workerId: authProvider.currentUser?.id,
                                workerName: authProvider.currentUser?.fullName,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Order marked as paid and processed')),
                              );
                            } catch (e) {
                              debugPrint('[POSOrders] processPaidOrder failed: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to process paid order: $e')),
                              );
                            }
                          } else {
                            provider.updateOrderStatus(order.id, status);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'served', child: Text('Mark as Served')),
                          const PopupMenuItem(
                              value: 'paid', child: Text('Mark as Paid')),
                          const PopupMenuItem(
                              value: 'cancelled', child: Text('Cancel')),
                        ],
                      ),
                      onTap: () => showModalBottomSheet(
                        context: context,
                        builder: (_) => _OrderDetailsSheet(
                            order: order, provider: provider),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final Order order;
  final DrinkProvider provider;
  const _OrderDetailsSheet({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order #${order.id}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...order.lines.map((line) {
            final drink = provider.getDrinkById(line.drinkId);
            return ListTile(
              leading: drink?.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(drink!.imageUrl!,
                          width: 32, height: 32, fit: BoxFit.cover),
                    )
                  : Text(drink?.emoji ?? '🍹',
                      style: const TextStyle(fontSize: 24)),
              title: Text(drink?.name ?? 'Unknown'),
              subtitle: Text('${line.quantityBottles} bottles'),
              trailing: Text(formatCurrency(line.lineTotal())),
            );
          }),
          const SizedBox(height: 8),
          Text('Status: ${order.status}'),
          const SizedBox(height: 8),
          Text('Created: ${order.createdAt}'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

