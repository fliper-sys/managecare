import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/text_styles.dart';

import '../../../../providers/business_logic_provider.dart';
import '../../../../services/business_logic/realestate_logic.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _loading = false;
  List<MaintenanceRequest> _requests = [];
  String _propertyIdFilter = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final provider = context.read<BusinessLogicProvider>();
      final requests = await provider.getMaintenanceRequests(_propertyIdFilter);
      setState(() {
        _requests = requests;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load maintenance requests: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openCreateTicket() async {
    final result = await Navigator.pushNamed(context, '/realestate/maintenance/create');
    if (result == true) {
      _loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Requests')),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty
                ? const Center(child: Text('No maintenance requests'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final r = _requests[index];
                      return Card(
                        child: ListTile(
                          title: Text(r.description,
                              style: AppTextStyles.body1),
                          subtitle: Text(
                              'Priority: ${r.priority} • Status: ${r.status} • ${r.createdAt.toLocal().toIso8601String().split('T').first}${r.assignedProviderName != null ? ' • Provider: ${r.assignedProviderName}' : ''}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // For now, no detail screen
                          },
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTicket,
        child: const Icon(Icons.add),
      ),
    );
  }
}
