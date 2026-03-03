import 'package:flutter/material.dart';

class StoreSelector extends StatelessWidget {
  final List<String> stores;
  final String selectedStore;
  final Function(String) onStoreChanged;

  const StoreSelector(
      {super.key,
      required this.stores,
      required this.selectedStore,
      required this.onStoreChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: selectedStore,
      onChanged: (String? newValue) {
        if (newValue != null) onStoreChanged(newValue);
      },
      items: stores.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
    );
  }
}

