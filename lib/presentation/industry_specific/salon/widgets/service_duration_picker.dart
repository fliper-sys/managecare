import 'package:flutter/material.dart';

class ServiceDurationPicker extends StatefulWidget {
  final Function(int) onDurationSelected;

  const ServiceDurationPicker({super.key, required this.onDurationSelected});

  @override
  State<ServiceDurationPicker> createState() => _ServiceDurationPickerState();
}

class _ServiceDurationPickerState extends State<ServiceDurationPicker> {
  late int selectedDuration = 30;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Duration: $selectedDuration minutes'),
        Slider(
            value: selectedDuration.toDouble(),
            min: 15,
            max: 180,
            divisions: 11,
            onChanged: (value) {
              setState(() => selectedDuration = value.toInt());
              widget.onDurationSelected(selectedDuration);
            }),
      ],
    );
  }
}

