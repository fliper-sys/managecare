import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/agri_provider.dart';
import '../../../../models/agri/livestock_group.dart';
import '../../../../models/agri/egg_record.dart';

class AnimalGroupDetailScreen extends StatefulWidget {
  final AnimalGroup group;
  final String businessId;

  const AnimalGroupDetailScreen({
    required this.group,
    required this.businessId,
    super.key,
  });

  @override
  State<AnimalGroupDetailScreen> createState() =>
      _AnimalGroupDetailScreenState();
}

class _AnimalGroupDetailScreenState extends State<AnimalGroupDetailScreen> {
  late AnimalGroup _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        backgroundColor: AppColors.agri,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Group Header Card
            Container(
              color: AppColors.agri.withOpacity(0.1),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(_group.emoji, style: const TextStyle(fontSize: 48)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _group.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _group.type.toUpperCase(),
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Count: ${_group.count} | Age: ${_group.ageWeeks}w | Maturity: ${_group.maturityWeek}w',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Key Stats
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard('Daily Feed', 
                      '${_group.dailyFeedKg().toStringAsFixed(2)} kg',
                      Icons.lunch_dining),
                  _buildStatCard('Weeks to Mature',
                      '${_group.weeksToMaturity()}w',
                      Icons.schedule),
                  _buildStatCard('Avg Eggs/Day',
                      _group.averageEggsPerDay().toStringAsFixed(1),
                      Icons.egg_outlined),
                  _buildStatCard('Feed Records',
                      '${_group.feedRecords.length}',
                      Icons.history),
                ],
              ),
            ),
            const Divider(),
            // Tabs for History
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: AppColors.agri,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Feed Records'),
                      Tab(text: 'Egg Records'),
                      Tab(text: 'Health'),
                    ],
                  ),
                  SizedBox(
                    height: 300,
                    child: TabBarView(
                      children: [
                        _buildFeedHistoryTab(),
                        _buildEggHistoryTab(),
                        _buildHealthHistoryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openRecordFeedDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Record Feed'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.agri,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_group.type.toLowerCase().contains('poultry'))
                    ElevatedButton.icon(
                      onPressed: () => _openRecordEggsDialog(),
                      icon: const Icon(Icons.egg_outlined),
                      label: const Text('Record Eggs'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFFFFC107),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openRecordHealthDialog(),
                    icon: const Icon(Icons.health_and_safety),
                    label: const Text('Record Health'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openEditDialog(),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Group'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppColors.agri, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedHistoryTab() {
    if (_group.feedRecords.isEmpty) {
      return Center(
        child: Text('No feed records yet',
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      itemCount: _group.feedRecords.length,
      itemBuilder: (ctx, i) {
        final record = _group.feedRecords[i];
        final date = DateTime.parse(record['date'] as String);
        return ListTile(
          leading: const Icon(Icons.lunch_dining),
          title: Text('${record['kgFed']} kg (${record['feedType']})'),
          subtitle: Text(
            '${date.day}/${date.month}/${date.year}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(record['notes'] ?? ''),
        );
      },
    );
  }

  Widget _buildEggHistoryTab() {
    if (_group.eggRecords.isEmpty) {
      return Center(
        child: Text('No egg records yet',
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      itemCount: _group.eggRecords.length,
      itemBuilder: (ctx, i) {
        final record = _group.eggRecords[i];
        return ListTile(
          leading: const Icon(Icons.egg_outlined),
          title: Text('${record.count} eggs'),
          subtitle: Text(
            '${record.date.day}/${record.date.month}/${record.date.year}',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildHealthHistoryTab() {
    if (_group.healthRecords.isEmpty) {
      return Center(
        child: Text('No health records yet',
            style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      itemCount: _group.healthRecords.length,
      itemBuilder: (ctx, i) {
        final record = _group.healthRecords[i];
        final date = DateTime.parse(record['date'] as String);
        return ListTile(
          leading: const Icon(Icons.health_and_safety),
          title: Text(record['eventType']),
          subtitle: Text(record['description'] ?? ''),
          trailing: Text('${date.day}/${date.month}'),
        );
      },
    );
  }

  Future<void> _openRecordFeedDialog() async {
    final kgCtrl = TextEditingController();
    final feedTypeCtrl = TextEditingController(text: 'grower');
    final notesCtrl = TextEditingController();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Feed Usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kgCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Kg'),
            ),
            TextField(
              controller: feedTypeCtrl,
              decoration: const InputDecoration(labelText: 'Feed Type'),
            ),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (res == true) {
      final kg = double.tryParse(kgCtrl.text) ?? 0.0;
      setState(() {
        _group.addFeedRecord(kg,
            feedType: feedTypeCtrl.text, notes: notesCtrl.text);
      });
      // Sync to Firestore
      if (mounted) {
        await context.read<AgriProvider>().updateGroupInFirestore(
            widget.businessId, _group,
            source: 'feed_record');
      }
    }
  }

  Future<void> _openRecordEggsDialog() async {
    final eggsCtrl = TextEditingController();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Eggs'),
        content: TextField(
          controller: eggsCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Egg Count'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (res == true) {
      final count = int.tryParse(eggsCtrl.text) ?? 0;
      setState(() {
        _group.eggRecords.add(
          EggRecord(
            count: count,
            date: DateTime.now(),
          ),
        );
      });
      if (mounted) {
        await context.read<AgriProvider>().updateGroupInFirestore(
            widget.businessId, _group,
            source: 'egg_record');
      }
    }
  }

  Future<void> _openRecordHealthDialog() async {
    final typeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Health Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Event (e.g., Vaccination, Illness)')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Notes / Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
        ],
      ),
    );

    if (res == true) {
      final eventType = typeCtrl.text.trim();
      final desc = descCtrl.text.trim();
      if (eventType.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an event type')));
        return;
      }
      setState(() {
        _group.addHealthRecord(eventType, description: desc);
      });
      if (mounted) {
        await context.read<AgriProvider>().updateGroupInFirestore(widget.businessId, _group, source: 'health_record');
      }
    }
  }

  Future<void> _openEditDialog() async {
    final nameCtrl = TextEditingController(text: _group.name);
    final countCtrl = TextEditingController(text: _group.count.toString());
    final ageCtrl = TextEditingController(text: _group.ageWeeks.toString());

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Count'),
            ),
            TextField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age (weeks)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (res == true) {
      setState(() {
        _group.name = nameCtrl.text.trim();
        _group.count = int.tryParse(countCtrl.text) ?? _group.count;
        _group.ageWeeks = int.tryParse(ageCtrl.text) ?? _group.ageWeeks;
      });
      if (mounted) {
        await context.read<AgriProvider>().updateGroupInFirestore(
            widget.businessId, _group,
            source: 'edit');
      }
    }
  }
}

// Import EggRecord
