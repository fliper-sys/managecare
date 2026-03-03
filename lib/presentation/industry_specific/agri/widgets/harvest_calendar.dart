import 'package:flutter/material.dart';

class HarvestCalendar extends StatelessWidget {
  final List<DateTime> harvestDates;

  const HarvestCalendar({super.key, required this.harvestDates});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: harvestDates
            .map((date) => ListTile(title: Text(date.toString())))
            .toList(),
      ),
    );
  }
}

