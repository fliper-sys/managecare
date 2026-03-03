import 'package:flutter/material.dart';

class CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final Function(String) onCategorySelected;

  const CategoryGrid(
      {super.key, required this.categories, required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => onCategorySelected(categories[index]),
          child: Card(
            child: Center(child: Text(categories[index])),
          ),
        );
      },
    );
  }
}

