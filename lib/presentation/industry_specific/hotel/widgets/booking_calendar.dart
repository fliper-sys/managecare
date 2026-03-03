import 'package:flutter/material.dart';

class BookingCalendar extends StatelessWidget {
  final Function(DateTime) onDateSelected;

  const BookingCalendar({super.key, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (selected != null) onDateSelected(selected);
      },
      child: const Text('Select Dates'),
    );
  }
}

