import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';

class PosProductCard extends StatelessWidget {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String emoji;
  final VoidCallback onAdd;

    const PosProductCard(
      {required this.id,
      required this.name,
      required this.price,
      required this.stock,
      this.emoji = '📦',
      required this.onAdd,
      super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: 'Product card: $name',
      button: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withOpacity(0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive emoji area
            LayoutBuilder(builder: (context, constraints) {
              final emojiSize = (constraints.maxWidth * 0.28).clamp(28.0, 56.0);
              return SizedBox(
                height: emojiSize + 8,
                child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(name,
                style:
                    AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₦${price.toStringAsFixed(2)}',
                  style: (Theme.of(context).textTheme.titleMedium ??
                          AppTextStyles.body2)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Tooltip(
                  message: stock > 0 ? 'Add $name to cart' : 'Out of stock',
                  child: Semantics(
                    button: true,
                    label: stock > 0 ? 'Add to cart' : 'Out of stock',
                    child: ElevatedButton(
                      onPressed: stock > 0 ? onAdd : null,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          backgroundColor: AppColors.primary),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

