import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/agri/livestock_group.dart';
import '../../../../providers/agri_provider.dart';
import '../../../../providers/business_provider.dart';

class AnimalDetailScreen extends StatefulWidget {
  final LivestockGroup group;
  const AnimalDetailScreen({super.key, required this.group});

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  final _eggsCtrl = TextEditingController();

  @override
  void dispose() {
    _eggsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AgriProvider>();
    final g = provider.getGroupById(widget.group.id) ?? widget.group;
    return Scaffold(
      appBar: AppBar(
          title: Text('${g.name} Details'), backgroundColor: AppColors.agri),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.name, style: AppTextStyles.heading4),
          const SizedBox(height: 8),
          Text('${g.count} birds • ${g.ageWeeks} weeks old',
              style: AppTextStyles.body1),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Feed per day: ${g.dailyFeedKg().toStringAsFixed(2)} kg',
                        style: AppTextStyles.subtitle2),
                    const SizedBox(height: 8),
                    Text('Weeks to maturity: ${g.weeksToMaturity()}',
                        style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    Text(
                        'Average eggs/day (7d): ${g.averageEggsPerDay().toStringAsFixed(1)}',
                        style: AppTextStyles.caption),
                  ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Record Eggs (today)', style: AppTextStyles.subtitle2),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _eggsCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(hintText: 'Number of eggs'))),
            const SizedBox(width: 8),
            ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.agri),
                onPressed: () async {
                  final n = int.tryParse(_eggsCtrl.text) ?? 0;
                  if (n <= 0) return;
                  final businessId =
                      context.read<BusinessProvider>().currentBusiness?.id ??
                          '';
                  await provider.recordEggs(g.id, n, businessId: businessId);
                  _eggsCtrl.clear();
                },
                child: const Text('Record'))
          ]),
          const SizedBox(height: 12),
          const Text('Recent Egg Records', style: AppTextStyles.subtitle2),
          const SizedBox(height: 8),
          Expanded(
              child: g.eggRecords.isEmpty
                  ? const Center(child: Text('No records'))
                  : ListView.builder(
                      itemCount: g.eggRecords.length,
                      itemBuilder: (context, i) {
                        final r = g.eggRecords[i];
                        return ListTile(
                            title: Text('${r.count} eggs'),
                            subtitle: Text(
                                r.date.toLocal().toString().split(' ')[0] +
                                    (r.note != null ? ' • ${r.note}' : '')));
                      })),
        ]),
      ),
    );
  }
}

