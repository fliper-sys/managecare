import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/gym_provider.dart';
import '../../../../data/models/gym_trainer_model.dart';

class TrainerManagementScreen extends StatelessWidget {
  const TrainerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GymProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Trainers')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: provider.trainers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final t = provider.trainers[index];
          return Card(
            child: ListTile(
              title: Text(t.name),
              subtitle: Text(t.specialty.isNotEmpty ? t.specialty : 'General'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      final nameCtrl = TextEditingController(text: t.name);
                      final specCtrl = TextEditingController(text: t.specialty);
                      showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                                title: const Text('Edit Trainer'),
                                content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                          controller: nameCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'Name')),
                                      TextField(
                                          controller: specCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'Specialty')),
                                    ]),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel')),
                                  ElevatedButton(
                                      onPressed: () {
                                        final updated = Trainer(
                                            id: t.id,
                                            name: nameCtrl.text.trim(),
                                            specialty: specCtrl.text.trim());
                                        provider.updateTrainer(index, updated);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Save'))
                                ],
                              ));
                    }),
                IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                                title: const Text('Remove Trainer'),
                                content: Text('Remove ${t.name}?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel')),
                                  ElevatedButton(
                                      onPressed: () {
                                        provider.removeTrainerById(t.id);
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Remove'))
                                ],
                              ));
                    })
              ]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final nameCtrl = TextEditingController();
          final specCtrl = TextEditingController();
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Add Trainer'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name')),
                      TextField(
                          controller: specCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Specialty')),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () {
                            provider.addTrainer(Trainer(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                name: nameCtrl.text.trim(),
                                specialty: specCtrl.text.trim()));
                            Navigator.pop(ctx);
                          },
                          child: const Text('Add'))
                    ],
                  ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

