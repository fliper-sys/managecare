import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';

/// Manage Services screen for the auto module.
///
/// Lets a shop create, edit, and delete presaved/"preset" jobs such as
/// "Engine Replacement" or "Auto Scanning" with a fixed workmanship price.
/// These presets then appear as selectable checkboxes when a receptionist
/// creates a new service order, so common jobs don't need to be re-priced
/// every time.
class AutoServicesScreen extends StatelessWidget {
  const AutoServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Services'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Consumer<AutoProvider>(
        builder: (context, provider, _) {
          final services = provider.services;

          if (provider.isLoadingData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (services.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.build_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No services yet.\nTap + to create a preset job like "Engine Replacement" or "Auto Scanning".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final service = services[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.build_circle_outlined,
                      color: AppColors.primary),
                  title: Text(service.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${formatCurrency(service.laborCost)} • ${service.estimatedDuration.inMinutes} min',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showServiceDialog(context, provider, service),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, provider, service),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(
            context, context.read<AutoProvider>(), null),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AutoProvider provider, ServiceTask service) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Remove "${service.name}" from your services list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final ok = await provider.deleteService(service.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete service')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showServiceDialog(
      BuildContext context, AutoProvider provider, ServiceTask? service) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ServiceDialog(provider: provider, service: service),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  final AutoProvider provider;
  final ServiceTask? service;

  const _ServiceDialog({required this.provider, this.service});

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _durationCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.service?.name ?? '');
    _priceCtrl = TextEditingController(
        text: widget.service != null ? widget.service!.laborCost.toString() : '');
    _durationCtrl = TextEditingController(
        text: widget.service != null
            ? widget.service!.estimatedDuration.inMinutes.toString()
            : '30');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Service' : 'New Service'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Service Name',
              hintText: 'e.g. Engine Replacement, Auto Scanning',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (Workmanship)',
              hintText: 'e.g. 10000',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Estimated Duration (minutes)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final duration = int.tryParse(_durationCtrl.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a service name')),
      );
      return;
    }
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }
    if (duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid duration in minutes')),
      );
      return;
    }

    setState(() => _saving = true);

    final service = ServiceTask(
      id: widget.service?.id ?? 'svc_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      laborCost: price,
      estimatedDuration: Duration(minutes: duration),
    );

    final ok = widget.service == null
        ? await widget.provider.addService(service)
        : await widget.provider.updateService(service);

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save service. Please try again.')),
      );
    }
  }
}
