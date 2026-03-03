import 'package:flutter/material.dart';

class RoomStatusGrid extends StatelessWidget {
  final List<Map<String, String>> rooms;

  const RoomStatusGrid({super.key, required this.rooms});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Card(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(room['number'] ?? ''),
                Text(room['status'] ?? '',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}

