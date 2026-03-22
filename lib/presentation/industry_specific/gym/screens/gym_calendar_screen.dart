import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/colors.dart';
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
    DateTime day,
    List<ClassSession> classes,
  ) {
    return classes.where((item) {
      return DateTime(item.start.year, item.start.month, item.start.day) ==
          DateTime(day.year, day.month, day.day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);
    _selected ??= DateTime.now();

    final dayClasses = _getEventsForDay(_selected!, provider.classes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Calendar'),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TableCalendar<ClassSession>(
              firstDay: DateTime.utc(2000, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focused,
              selectedDayPredicate: (day) {
                return _selected != null &&
                    DateTime(day.year, day.month, day.day) ==
                        DateTime(
                          _selected!.year,
                          _selected!.month,
                          _selected!.day,
                        );
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selected = selectedDay;
                  _focused = focusedDay;
                });
              },
              eventLoader: (day) => _getEventsForDay(day, provider.classes),
              calendarStyle: const CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Classes on ${DateFormat('yyyy-MM-dd').format(_selected!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: dayClasses.isEmpty
                        ? Center(
                            child: Text(
                              'No classes for this day',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: dayClasses.length,
                            itemBuilder: (context, index) {
                              final gymClass = dayClasses[index];
                              return Card(
                                child: ListTile(
                                  title: Text(gymClass.title),
                                  subtitle: Text(
                                    '${DateFormat('h:mm a').format(gymClass.start)} - ${DateFormat('h:mm a').format(gymClass.end)}',
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      if (provider.members.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('No members to book'),
                                          ),
                                        );
                                        return;
                                      }
                                      try {
                                        provider.bookClass(
                                          provider.members.first.id,
                                          gymClass.id,
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Booked successfully'),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Could not book: $e'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Book'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
