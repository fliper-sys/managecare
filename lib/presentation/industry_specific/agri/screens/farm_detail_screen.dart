import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/agri_provider.dart';
import '../../../../core/theme/colors.dart';

class FarmDetailScreen extends StatefulWidget {
  final Map<String, dynamic> farm;
  const FarmDetailScreen({super.key, required this.farm});

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> {
  final _taskController = TextEditingController();
  final _cropController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    _cropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agri = context.watch<AgriProvider>();
    final farmId = widget.farm['id'] as String;
    final crops = agri.getCropsForFarm(farmId);
    final tasks =
        agri.tasks.where((t) => (t['farmId'] ?? '') == farmId).toList();

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.farm['name'] ?? 'Farm'),
          backgroundColor: AppColors.agri),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.farm['location'] ?? '',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          const Text('Crops', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (crops.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('No crops yet.'))),
          if (crops.isNotEmpty)
            ...crops.map((c) => Card(
                  child: ListTile(
                    title: Text(c['name'] ?? 'Crop'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => context
                          .read<AgriProvider>()
                          .removeCropById(c['id'] ?? ''),
                    ),
                  ),
                )),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _cropController,
                    decoration:
                        const InputDecoration(labelText: 'New crop name'))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final name = _cropController.text.trim();
                if (name.isEmpty) return;
                final crop = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': name,
                  'status': 'Active',
                  'farmId': farmId
                };
                context.read<AgriProvider>().addCrop(crop);
                _cropController.clear();
              },
              child: const Text('Add'),
            )
          ]),
          const SizedBox(height: 16),
          const Text('Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('No tasks for this farm.'))),
          if (tasks.isNotEmpty)
            ...tasks.map((t) => Card(
                  child: ListTile(
                    leading: Checkbox(
                        value: (t['done'] ?? false) as bool,
                        onChanged: (_) => context
                            .read<AgriProvider>()
                            .toggleTaskDone(t['id'] ?? '')),
                    title: Text(t['title'] ?? t['name'] ?? ''),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => context
                            .read<AgriProvider>()
                            .removeTask(t['id'] ?? '')),
                  ),
                )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(labelText: 'New task'))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final title = _taskController.text.trim();
                if (title.isEmpty) return;
                final task = {
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': title,
                  'done': false,
                  'farmId': farmId
                };
                context.read<AgriProvider>().addTask(task);
                _taskController.clear();
              },
              child: const Text('Add'),
            )
          ])
        ]),
      ),
    );
  }
}

