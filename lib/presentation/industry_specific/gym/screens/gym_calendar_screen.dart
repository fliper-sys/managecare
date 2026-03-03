import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../providers/gym_provider.dart';

class GymCalendarScreen extends StatefulWidget {
  const GymCalendarScreen({super.key});

  @override
  State<GymCalendarScreen> createState() => _GymCalendarScreenState();
}

class _GymCalendarScreenState extends State<GymCalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;

  List<ClassSession> _getEventsForDay(
      DateTime day, List<ClassSession> classes) {
    return classes
        .where((c) =>
            DateTime(c.start.year, c.start.month, c.start.day) ==
            DateTime(day.year, day.month, day.day))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);
    _selected ??= DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Class Calendar')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TableCalendar<ClassSession>(
              firstDay: DateTime.utc(2000, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focused,
              selectedDayPredicate: (d) =>
                  _selected != null &&
                  DateTime(d.year, d.month, d.day) ==
                      DateTime(
                          _selected!.year, _selected!.month, _selected!.day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selected = selectedDay;
                  _focused = focusedDay;
                });
              },
              eventLoader: (day) => _getEventsForDay(day, provider.classes),
              calendarStyle: const CalendarStyle(
                markerDecoration:
                    BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Classes on ${_selected!.toLocal().toIso8601String().split('T').first}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Builder(builder: (ctx) {
                      final list =
                          _getEventsForDay(_selected!, provider.classes);
                      if (list.isEmpty) {
                        return const Center(
                            child: Text('No classes for this day'));
                      }
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final c = list[index];
                          return Card(
                            child: ListTile(
                              title: Text(c.title),
                              subtitle: Text(
                                  '${c.start.hour.toString().padLeft(2, '0')}:${c.start.minute.toString().padLeft(2, '0')} - ${c.end.hour.toString().padLeft(2, '0')}:${c.end.minute.toString().padLeft(2, '0')}'),
                              trailing: ElevatedButton(
                                  onPressed: () async {
                                    if (provider.members.isEmpty) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('No members to book')));
                                      return;
                                    }
                                    try {
                                      provider.bookClass(
                                          provider.members.first.id, c.id);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Booked successfully')));
                                    } catch (e) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Could not book: $e')));
                                    }
                                  },
                                  child: const Text('Book')),
                            ),
                          );
                        },
                      );
                    }),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

