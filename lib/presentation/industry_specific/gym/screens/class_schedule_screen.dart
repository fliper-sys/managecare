import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../data/models/gym_trainer_model.dart';

class ClassScheduleScreen extends StatelessWidget {
  const ClassScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Class Schedule')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final c = provider.upcomingClasses()[index];
          final start = c.start.toLocal();
          final timeStr =
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(c.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '$timeStr • ${c.bookedMemberIds.length}/${c.capacity} spots'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                            'Trainer: ${provider.trainers.firstWhere((t) => t.id == c.trainerId, orElse: () => Trainer(id: 'n/a', name: 'TBD')).name}'),
                        const SizedBox(height: 8),
                        Text('Capacity: ${c.capacity}'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          child: const Text('Book (first member)'),
                          onPressed: () {
                            if (provider.members.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No members to book')));
                              return;
                            }
                            try {
                              provider.bookClass(
                                  provider.members.first.id, c.id);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Booked')));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Could not book: $e')));
                            }
                          },
                        )
                      ],
                    ),
                  ),
                );
              },
              trailing: ElevatedButton(
                child: const Text('Book'),
                onPressed: () {
                  if (provider.members.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No members to book')));
                    return;
                  }
                  try {
                    provider.bookClass(provider.members.first.id, c.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Booked ${c.title}')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not book: $e')));
                  }
                },
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: provider.upcomingClasses().length,
      ),
    );
  }
}

