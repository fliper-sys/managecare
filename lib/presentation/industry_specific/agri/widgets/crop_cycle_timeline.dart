import 'package:flutter/material.dart';

class CropCycleTimeline extends StatelessWidget {
  final List<Map<String, String>> stages;

  const CropCycleTimeline({super.key, required this.stages});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(label: Text(stages[index]['name'] ?? '')),
          );
        },
      ),
    );
  }
}

