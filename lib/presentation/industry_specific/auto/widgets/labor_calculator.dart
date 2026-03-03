import 'package:flutter/material.dart';

class LaborCalculator extends StatefulWidget {
  final double hourlyRate;
  final Function(double) onLaborCalculated;

  const LaborCalculator(
      {super.key, required this.hourlyRate, required this.onLaborCalculated});

  @override
  State<LaborCalculator> createState() => _LaborCalculatorState();
}

class _LaborCalculatorState extends State<LaborCalculator> {
  late final TextEditingController _hoursController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
            controller: _hoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Hours')),
        ElevatedButton(
          onPressed: () {
            final hours = double.tryParse(_hoursController.text) ?? 0;
            widget.onLaborCalculated(hours * widget.hourlyRate);
          },
          child: const Text('Calculate'),
        )
      ],
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }
}

