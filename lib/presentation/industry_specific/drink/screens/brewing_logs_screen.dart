import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/colors.dart';
import '../../../../providers/business_provider.dart';

class BrewingLogsScreen extends StatefulWidget {
  const BrewingLogsScreen({super.key});

  @override
  State<BrewingLogsScreen> createState() => _BrewingLogsScreenState();
}

class _BrewingLogsScreenState extends State<BrewingLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business == null) return setState(() => _isLoading = false);

      final snap = await FirebaseFirestore.instance
          .collection('brewingLogs')
          .where('businessId', isEqualTo: business.id)
          .orderBy('startedAt', descending: true)
          .get();

      setState(() {
        _logs = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load logs';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Brewing Logs'),
          backgroundColor: AppColors.primary),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _logs.isEmpty
                  ? const Center(child: Text('No brewing logs'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final l = _logs[index];
                        final started = (l['startedAt'] is Timestamp)
                            ? (l['startedAt'] as Timestamp)
                                .toDate()
                                .toString()
                                .split(' ')[0]
                            : (l['startedAt']?.toString() ?? '');
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.local_drink),
                            title:
                                Text(l['batchNumber']?.toString() ?? 'Batch'),
                            subtitle: Text('Started: $started'),
                            trailing:
                                Text('Status: ${l['status'] as String? ?? ''}'),
                          ),
                        );
                      },
                    ),
    );
  }
}

