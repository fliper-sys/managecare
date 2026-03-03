import 'package:flutter/material.dart';

class DateRangePicker extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime, DateTime) onDateRangeChanged;

  const DateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
  });

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();
    startDate = widget.startDate;
    endDate = widget.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
          initialDateRange: DateTimeRange(start: startDate, end: endDate),
        );
        if (range != null) {
          setState(() {
            startDate = range.start;
            endDate = range.end;
          });
          widget.onDateRangeChanged(range.start, range.end);
        }
      },
      icon: const Icon(Icons.date_range),
      label: Text(
        '${startDate.day}/${startDate.month} - ${endDate.day}/${endDate.month}',
      ),
    );
  }
}

