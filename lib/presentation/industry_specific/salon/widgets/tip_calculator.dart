import 'package:flutter/material.dart';
import '../../../../core/utils/currency.dart';

class TipCalculator extends StatefulWidget {
  final double totalAmount;
  final Function(double) onTipCalculated;

  const TipCalculator(
      {super.key, required this.totalAmount, required this.onTipCalculated});

  @override
  State<TipCalculator> createState() => _TipCalculatorState();
}

class _TipCalculatorState extends State<TipCalculator> {
  late double tipPercent = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Tip: ${formatCurrency(widget.totalAmount * tipPercent / 100)}'),
        Slider(
            value: tipPercent,
            min: 0,
            max: 30,
            divisions: 30,
            onChanged: (value) {
              setState(() => tipPercent = value);
              widget.onTipCalculated(widget.totalAmount * value / 100);
            }),
      ],
    );
  }
}

