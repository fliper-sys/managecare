import 'package:flutter/material.dart';

class OrderTypeSelector extends StatefulWidget {
  final Function(String) onTypeSelected;

  const OrderTypeSelector({super.key, required this.onTypeSelected});

  @override
  State<OrderTypeSelector> createState() => _OrderTypeSelectorState();
}

class _OrderTypeSelectorState extends State<OrderTypeSelector> {
  late String selectedType = 'Dine-In';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['Dine-In', 'Takeout', 'Delivery']
          .map((type) => FilterChip(
                label: Text(type),
                selected: selectedType == type,
                onSelected: (bool selected) {
                  setState(() => selectedType = selected ? type : '');
                  if (selected) widget.onTypeSelected(type);
                },
              ))
          .toList(),
    );
  }
}

