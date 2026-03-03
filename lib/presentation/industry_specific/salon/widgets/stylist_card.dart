import 'package:flutter/material.dart';

class StylistCard extends StatelessWidget {
  final String name;
  final List<String> specializations;
  final double rating;
  final VoidCallback onTap;

  const StylistCard({
    super.key,
    required this.name,
    required this.specializations,
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(specializations.join(', ')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star, color: Colors.amber),
          Text(rating.toString()),
        ]),
        onTap: onTap,
      ),
    );
  }
}

