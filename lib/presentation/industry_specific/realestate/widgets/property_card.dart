import 'package:flutter/material.dart';

class PropertyCard extends StatelessWidget {
  final String id;
  final String title;
  final String price;
  final String location;
  final VoidCallback? onTap;

  const PropertyCard(
      {super.key,
      required this.id,
      required this.title,
      required this.price,
      required this.location,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: ListTile(
          leading: const Icon(Icons.home),
          title: Text(title),
          subtitle: Text(location),
          trailing:
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

