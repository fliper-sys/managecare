import 'package:flutter/material.dart';

class DiscountCalculator extends StatefulWidget {
  final double originalPrice;
  final Function(double) onDiscountCalculated;

  const DiscountCalculator(
      {super.key,
      required this.originalPrice,
      required this.onDiscountCalculated});

  @override
  State<DiscountCalculator> createState() => _DiscountCalculatorState();
}

class _DiscountCalculatorState extends State<DiscountCalculator> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Original: \$${widget.originalPrice.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
        ElevatedButton(
            onPressed: () {}, child: const Text('Calculate Discount'))
      ],
    );
  }
}

