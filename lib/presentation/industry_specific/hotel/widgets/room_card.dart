import 'package:flutter/material.dart';

class RoomCard extends StatelessWidget {
  final String number;
  final String type;
  final String status;
  final VoidCallback? onTap;

  const RoomCard(
      {super.key,
      required this.number,
      required this.type,
      required this.status,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = status.toLowerCase().contains('avail');
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Room $number',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(type),
              const SizedBox(height: 8),
              Chip(
                  label: Text(status),
                  backgroundColor:
                      available ? Colors.green[100] : Colors.red[100]),
            ],
          ),
        ),
      ),
    );
  }
}

