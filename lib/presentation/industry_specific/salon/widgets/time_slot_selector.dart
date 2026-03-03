import 'package:flutter/material.dart';

class TimeSlotSelector extends StatefulWidget {
  final List<String> availableSlots;
  final Function(String) onSlotSelected;

  const TimeSlotSelector(
      {super.key, required this.availableSlots, required this.onSlotSelected});

  @override
  State<TimeSlotSelector> createState() => _TimeSlotSelectorState();
}

class _TimeSlotSelectorState extends State<TimeSlotSelector> {
  late String selectedSlot = '';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: widget.availableSlots
          .map((slot) => FilterChip(
                label: Text(slot),
                selected: selectedSlot == slot,
                onSelected: (bool selected) {
                  setState(() => selectedSlot = selected ? slot : '');
                  if (selected) widget.onSlotSelected(slot);
                },
              ))
          .toList(),
    );
  }
}

