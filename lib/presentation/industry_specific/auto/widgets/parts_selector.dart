import 'package:flutter/material.dart';

class PartsSelector extends StatefulWidget {
  final List<String> parts;
  final Function(List<String>) onPartsSelected;

  const PartsSelector(
      {super.key, required this.parts, required this.onPartsSelected});

  @override
  State<PartsSelector> createState() => _PartsSelectorState();
}

class _PartsSelectorState extends State<PartsSelector> {
  late List<String> selectedParts = [];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: widget.parts
          .map((part) => CheckboxListTile(
                title: Text(part),
                value: selectedParts.contains(part),
                onChanged: (bool? value) {
                  setState(() {
                    if (value ?? false) {
                      selectedParts.add(part);
                    } else {
                      selectedParts.remove(part);
                    }
                    widget.onPartsSelected(selectedParts);
                  });
                },
              ))
          .toList(),
    );
  }
}

