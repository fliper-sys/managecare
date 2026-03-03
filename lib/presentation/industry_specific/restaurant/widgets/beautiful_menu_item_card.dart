import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../providers/restaurant_provider.dart';

class BeautifulMenuItemCard extends StatefulWidget {
  final MenuItem item;
  final VoidCallback? onAddToCart;

  const BeautifulMenuItemCard(
      {super.key, required this.item, this.onAddToCart});

  @override
  State<BeautifulMenuItemCard> createState() => _BeautifulMenuItemCardState();
}

class _BeautifulMenuItemCardState extends State<BeautifulMenuItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPressed() {
    _animationController.forward().then((_) => _animationController.reverse());
    widget.onAddToCart?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isUnavailable = !widget.item.available;

    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.95).animate(_animationController),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge with availability indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(widget.item.category,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                    if (isUnavailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Unavailable',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Item name
                Text(widget.item.name,
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                // Description and rating
                if (widget.item.description != null)
                  Text(widget.item.description!,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (widget.item.rating != null)
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                          '${widget.item.rating!.toStringAsFixed(1)} (${widget.item.reviewCount ?? 0})',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade700)),
                    ],
                  ),
                const Spacer(),
                // Price and button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatCurrency(widget.item.price),
                        style: AppTextStyles.heading5
                            .copyWith(color: AppColors.primary)),
                    GestureDetector(
                      onTap: widget.item.available ? _onPressed : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.item.available
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add,
                            size: 18,
                            color: widget.item.available
                                ? Colors.white
                                : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

