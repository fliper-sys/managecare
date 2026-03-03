import 'package:flutter/material.dart';

class LivestockCard extends StatelessWidget {
  final String animalType;
  final int count;
  final String status;
  final VoidCallback onTap;

  const LivestockCard({
    super.key,
    required this.animalType,
    required this.count,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(animalType),
        subtitle: Text('Count: $count • Status: $status'),
        onTap: onTap,
      ),
    );
  }
}

