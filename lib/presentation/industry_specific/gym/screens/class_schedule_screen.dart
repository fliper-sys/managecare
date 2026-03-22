import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../data/models/gym_trainer_model.dart';

class ClassScheduleScreen extends StatelessWidget {
  const ClassScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);
    final classes = provider.upcomingClasses();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Schedule'),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: Colors.grey[50],
      body: classes.isEmpty
          ? Center(
              child: Text(
                'No upcoming classes scheduled',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final gymClass = classes[index];
                final start = gymClass.start.toLocal();
                final timeStr = DateFormat('MMM d, h:mm a').format(start);
                final trainer = provider.trainers.firstWhere(
                  (item) => item.id == gymClass.trainerId,
                  orElse: () => Trainer(id: 'n/a', name: 'TBD'),
                );

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(
                      gymClass.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '$timeStr\n${trainer.name} - ${gymClass.bookedMemberIds.length}/${gymClass.capacity} booked',
                    ),
                    isThreeLine: true,
                    onTap: () => _showDetails(context, provider, gymClass, trainer),
                    trailing: ElevatedButton(
                      onPressed: () => _bookFirstMember(context, provider, gymClass),
                      child: const Text('Book'),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: classes.length,
            ),
    );
  }

  void _showDetails(
    BuildContext context,
    GymProvider provider,
    ClassSession gymClass,
    Trainer trainer,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gymClass.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Trainer: ${trainer.name}'),
            const SizedBox(height: 8),
            Text('Starts: ${DateFormat('MMM d, h:mm a').format(gymClass.start)}'),
            Text('Ends: ${DateFormat('MMM d, h:mm a').format(gymClass.end)}'),
            const SizedBox(height: 8),
            Text('Capacity: ${gymClass.capacity}'),
            const SizedBox(height: 8),
            Text('Booked: ${gymClass.bookedMemberIds.length}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _bookFirstMember(context, provider, gymClass),
              child: const Text('Book first member'),
            ),
          ],
        ),
      ),
    );
  }

  void _bookFirstMember(
    BuildContext context,
    GymProvider provider,
    ClassSession gymClass,
  ) {
    if (provider.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members to book')),
      );
      return;
    }
    try {
      provider.bookClass(provider.members.first.id, gymClass.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booked ${gymClass.title}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not book: $e')),
      );
    }
  }
}
