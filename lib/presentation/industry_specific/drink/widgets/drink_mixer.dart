import 'package:flutter/material.dart';

class DrinkMixer extends StatefulWidget {
  final List<String> ingredients;
  final Function(List<String>) onRecipeCreated;

  const DrinkMixer(
      {super.key, required this.ingredients, required this.onRecipeCreated});

  @override
  State<DrinkMixer> createState() => _DrinkMixerState();
}

class _DrinkMixerState extends State<DrinkMixer> {
  late List<String> selected = [];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: widget.ingredients
          .map((ingredient) => FilterChip(
                label: Text(ingredient),
                selected: selected.contains(ingredient),
                onSelected: (bool value) {
                  setState(() {
                    if (value) {
                      selected.add(ingredient);
                    } else {
                      selected.remove(ingredient);
                    }
                    widget.onRecipeCreated(selected);
                  });
                },
              ))
          .toList(),
    );
  }
}

