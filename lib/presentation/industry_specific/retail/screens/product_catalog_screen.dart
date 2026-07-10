import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/retail_provider.dart';
import '../widgets/pos_product_card.dart';

class ProductCatalogScreen extends StatelessWidget {
  const ProductCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RetailProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Product Catalog'),
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: colorScheme.onSurface)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int crossAxisCount = 2;
            if (width >= 1200) {
              crossAxisCount = 6;
            } else if (width >= 800) {
              crossAxisCount = 4;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.78,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: provider.products.length,
              itemBuilder: (context, index) {
                final p = provider.products[index];
                return PosProductCard(
                    id: p.id,
                    name: p.name,
                    price: p.price,
                    stock: p.stock as int,
                    emoji: p.emoji,
                    onAdd: () => provider.addToCart(p.id));
              },
            );
          },
        ),
      ),
    );
  }
}

