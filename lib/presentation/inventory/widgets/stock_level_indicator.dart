import 'package:flutter/material.dart';

class StockLevelIndicator extends StatelessWidget {
  final int current;
  final int minimum;
  final int maximum;

  const StockLevelIndicator({
    super.key,
    required this.current,
    required this.minimum,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (current / maximum).clamp(0.0, 1.0);
    final color = percentage < 0.2
        ? Colors.red
        : percentage < 0.5
            ? Colors.orange
            : Colors.green;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Stock Level'),
            Text('$current / $maximum'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

