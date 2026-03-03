import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/drink_provider.dart';

class DrinkInventoryScreen extends StatefulWidget {
  const DrinkInventoryScreen({super.key});

  @override
  State<DrinkInventoryScreen> createState() => _DrinkInventoryScreenState();
}

class _DrinkInventoryScreenState extends State<DrinkInventoryScreen> {
  Future<void> _refreshInventory() async {
    // Simulate a refresh by waiting a moment
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Inventory'), backgroundColor: Colors.brown),
      body: Consumer<DrinkProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: _refreshInventory,
            color: Colors.brown,
            child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.drinks.length,
            itemBuilder: (context, index) {
              final drink = provider.drinks[index];
              final stock = provider.getStock(drink.id);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: drink.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(drink.imageUrl!,
                                  width: 48, height: 48, fit: BoxFit.cover),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.brown[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(drink.emoji,
                                  style: const TextStyle(fontSize: 28)),
                            ),
                      title: Text(drink.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${stock?.bottles ?? 0} bottles • ${stock?.cartons ?? 0} cartons',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StockButton(
                            icon: Icons.remove,
                            label: 'B-',
                            onPressed: () =>
                                provider.adjustStock(drink.id, bottleDelta: -1),
                          ),
                          _StockButton(
                            icon: Icons.add,
                            label: 'B+',
                            onPressed: () =>
                                provider.adjustStock(drink.id, bottleDelta: 1),
                          ),
                          _StockButton(
                            icon: Icons.remove_circle_outline,
                            label: 'C-',
                            onPressed: () =>
                                provider.adjustStock(drink.id, cartonDelta: -1),
                          ),
                          _StockButton(
                            icon: Icons.add_circle_outline,
                            label: 'C+',
                            onPressed: () =>
                                provider.adjustStock(drink.id, cartonDelta: 1),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit'),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => _AddStockDialog(
                                drink: drink,
                                provider: provider,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ));
            },
          ));
        }
      
}

class _StockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _StockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class _AddStockDialog extends StatefulWidget {
  final DrinkItem drink;
  final DrinkProvider provider;
  const _AddStockDialog({required this.drink, required this.provider});

  @override
  State<_AddStockDialog> createState() => _AddStockDialogState();
}

class _AddStockDialogState extends State<_AddStockDialog> {
  int bottles = 0;
  int cartons = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Stock for ${widget.drink.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Bottles:'),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => bottles = int.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Cartons:'),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => cartons = int.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text('Add'),
          onPressed: () {
            widget.provider.adjustStock(widget.drink.id,
                bottleDelta: bottles, cartonDelta: cartons);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

