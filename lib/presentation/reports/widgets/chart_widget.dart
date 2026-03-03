import 'package:flutter/material.dart';

class ChartWidget extends StatelessWidget {
  final String title;

  const ChartWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child:
                    Text('Chart Placeholder - Integrate with charts_flutter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

