import 'package:flutter/material.dart';

class InputUsageChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const InputUsageChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text('Usage Chart (${data.length} items)'),
      ),
    );
  }
}

