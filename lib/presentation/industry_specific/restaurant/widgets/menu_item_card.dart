import 'package:flutter/material.dart';

class MenuItemCard extends StatelessWidget {
  final String name;
  final String price;
  final String description;
  final VoidCallback? onTap;

  const MenuItemCard(
      {super.key,
      required this.name,
      required this.price,
      required this.description,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu, size: 34),
              const SizedBox(height: 8),
              Text(name, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

