import 'package:flutter/material.dart';

class ModifierSelector extends StatefulWidget {
  final List<String> modifiers;
  final Function(List<String>) onModifiersSelected;

  const ModifierSelector(
      {super.key, required this.modifiers, required this.onModifiersSelected});

  @override
  State<ModifierSelector> createState() => _ModifierSelectorState();
}

class _ModifierSelectorState extends State<ModifierSelector> {
  late List<String> selected = [];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: widget.modifiers
          .map((modifier) => CheckboxListTile(
                title: Text(modifier),
                value: selected.contains(modifier),
                onChanged: (bool? value) {
                  setState(() {
                    if (value ?? false) {
                      selected.add(modifier);
                    } else {
                      selected.remove(modifier);
                    }
                    widget.onModifiersSelected(selected);
                  });
                },
              ))
          .toList(),
    );
  }
}

