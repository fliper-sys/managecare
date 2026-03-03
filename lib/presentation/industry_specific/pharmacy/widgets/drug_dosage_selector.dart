import 'package:flutter/material.dart';

class DrugDosageSelector extends StatelessWidget {
  final String drugName;
  final List<String> dosages;
  final ValueChanged<String>? onSelected;

  const DrugDosageSelector(
      {super.key,
      required this.drugName,
      required this.dosages,
      this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(drugName, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: dosages
              .map((d) => ChoiceChip(
                  label: Text(d),
                  selected: false,
                  onSelected: (_) => onSelected?.call(d)))
              .toList(),
        )
      ],
    );
  }
}

