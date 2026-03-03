import 'package:flutter/material.dart';

class PourSizeSelector extends StatefulWidget {
  final Function(double) onSizeSelected;

  const PourSizeSelector({super.key, required this.onSizeSelected});

  @override
  State<PourSizeSelector> createState() => _PourSizeSelectorState();
}

class _PourSizeSelectorState extends State<PourSizeSelector> {
  late double selectedSize = 1.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Pour Size: ${selectedSize}oz'),
        Slider(
            value: selectedSize,
            min: 0.5,
            max: 3.0,
            divisions: 10,
            onChanged: (value) {
              setState(() => selectedSize = value);
              widget.onSizeSelected(value);
            }),
      ],
    );
  }
}

