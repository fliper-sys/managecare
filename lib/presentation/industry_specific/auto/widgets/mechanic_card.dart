import 'package:flutter/material.dart';

class MechanicCard extends StatelessWidget {
  final String name;
  final double rating;

  const MechanicCard({super.key, required this.name, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(name),
        subtitle: Text('Rating: ${rating.toStringAsFixed(1)}'),
        trailing: ElevatedButton(onPressed: () {}, child: const Text('Assign')),
      ),
    );
  }
}

