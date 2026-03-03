import 'package:flutter/material.dart';

class CalendarWidget extends StatelessWidget {
  final Function(DateTime) onDateSelected;

  const CalendarWidget({super.key, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 90)),
          );
          if (selected != null) onDateSelected(selected);
        },
        child: const Text('Select Date'),
      ),
    );
  }
}

