import 'package:flutter/material.dart';

class ServiceCard extends StatelessWidget {
  final String name;
  final String duration;
  final String price;
  final VoidCallback? onTap;

  const ServiceCard(
      {super.key,
      required this.name,
      required this.duration,
      required this.price,
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
              const Icon(Icons.content_cut, size: 36),
              const SizedBox(height: 8),
              Text(name, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(duration),
              const SizedBox(height: 6),
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

