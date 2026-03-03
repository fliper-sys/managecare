import 'package:flutter/material.dart';

class PatientSearch extends StatelessWidget {
  final ValueChanged<String>? onSelected;

  const PatientSearch({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search), hintText: 'Search patients...'),
      onSubmitted: (value) => onSelected?.call(value),
    );
  }
}

