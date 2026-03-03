import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../core/theme/text_styles.dart';
import 'add_drink_screen.dart';

class DrinkManagementScreen extends StatelessWidget {
  const DrinkManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DrinkProvider>(context);
    final drinks = provider.drinks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drinks Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: drinks.isEmpty
            ? const Center(child: Text('No drinks found'))
            : ListView.separated(
                itemCount: drinks.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final d = drinks[idx];
                  final stock = provider.getTotalBottles(d.id);
                  return ListTile(
                    leading: d.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: CachedNetworkImage(
                              imageUrl: d.imageUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported,
                                    size: 24),
                              ),
                            ),
                          )
                        : Text(d.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(d.name, style: AppTextStyles.heading5),
                    subtitle: Text(
                        '${d.category} • \$${d.pricePerBottle.toStringAsFixed(2)} • Stock: $stock'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => AddDrinkScreen(editDrink: d)));
                        } else if (v == 'delete') {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Drink?'),
                              content: Text(
                                  'Are you sure you want to delete ${d.name}?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            // Delete from repository and local lists
                            try {
                              if (provider.repository != null) {
                                await provider.repository!.deleteDrink(d.id);
                              }
                              // Remove from local state
                              provider.drinks.removeWhere((x) => x.id == d.id);
                              provider.inventory
                                  .removeWhere((s) => s.drinkId == d.id);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${d.name} deleted')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Delete failed: $e')),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddDrinkScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

