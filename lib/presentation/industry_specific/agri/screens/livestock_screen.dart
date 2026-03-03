import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/agri_provider.dart';
import 'add_livestock_screen.dart';
import 'animal_detail_screen.dart';

class LivestockScreen extends StatefulWidget {
  const LivestockScreen({super.key});

  @override
  State<LivestockScreen> createState() => _LivestockScreenState();
}

class _LivestockScreenState extends State<LivestockScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgriProvider>();
    final groups = provider.livestockGroups;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Livestock'), backgroundColor: AppColors.agri),
      body: groups.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('No livestock groups yet'),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddLivestockScreen())),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.agri),
                    child: const Text('Add Group'))
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.pets, color: AppColors.agri),
                    title: Text(g.name, style: AppTextStyles.heading4),
                    subtitle: Text(
                        '${g.count} birds • ${g.ageWeeks} weeks • ${g.averageEggsPerDay().toStringAsFixed(1)} eggs/day'),
                    trailing:
                        Text('${g.dailyFeedKg().toStringAsFixed(1)} kg/day'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AnimalDetailScreen(group: g))),
                  ),
                );
              }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.agri,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddLivestockScreen())),
      ),
    );
  }
}

