import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../data/models/gym_trainer_model.dart';

class TrainerManagementScreen extends StatelessWidget {
  const TrainerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trainers'),
        backgroundColor: AppColors.primary,
      ),
      backgroundColor: Colors.grey[50],
      body: provider.trainers.isEmpty
          ? Center(
              child: Text(
                'No trainers found',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: provider.trainers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final trainer = provider.trainers[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(
                        trainer.name.isNotEmpty
                            ? trainer.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(trainer.name),
                    subtitle: Text(
                      trainer.specialty.isNotEmpty
                          ? trainer.specialty
                          : 'General',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showTrainerDialog(
                            context,
                            provider,
                            index: index,
                            trainer: trainer,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _confirmDelete(context, provider, trainer),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTrainerDialog(context, provider),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Trainer'),
      ),
    );
  }

  void _showTrainerDialog(
    BuildContext context,
    GymProvider provider, {
    int? index,
    Trainer? trainer,
  }) {
    final nameCtrl = TextEditingController(text: trainer?.name ?? '');
    final specCtrl = TextEditingController(text: trainer?.specialty ?? '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trainer == null ? 'Add Trainer' : 'Edit Trainer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: specCtrl,
              decoration: const InputDecoration(labelText: 'Specialty'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = Trainer(
                id: trainer?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                specialty: specCtrl.text.trim(),
              );
              if (updated.name.isEmpty) return;
              if (trainer == null) {
                provider.addTrainer(updated);
              } else {
                provider.updateTrainer(index!, updated);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    GymProvider provider,
    Trainer trainer,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Trainer'),
        content: Text('Remove ${trainer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.removeTrainerById(trainer.id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
