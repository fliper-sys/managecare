import 'package:flutter/material.dart';

class FarmCard extends StatelessWidget {
  final String farmName;
  final String location;
  final double area;
  final VoidCallback onTap;

  const FarmCard(
      {super.key,
      required this.farmName,
      required this.location,
      required this.area,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(farmName),
        subtitle: Text('$location • ${area}ha'),
        onTap: onTap,
      ),
    );
  }
}

