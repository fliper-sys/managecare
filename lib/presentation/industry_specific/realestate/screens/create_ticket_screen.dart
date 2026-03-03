import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/business_logic_provider.dart';
import '../../../../services/business_logic/realestate_logic.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _propertyController = TextEditingController();
  final _descController = TextEditingController();
  String _priority = 'medium';
  bool _submitting = false;

  // Service providers for assignment
  List<ServiceProvider> _providers = [];
  String? _selectedProviderId;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final bprov = context.read<BusinessLogicProvider>();
      final list = await bprov.getServiceProviders();
      if (mounted) setState(() => _providers = list);
    } catch (e) {
      // non-fatal: show a toast if desired
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load providers: $e')));
    }
  }

  @override
  void dispose() {
    _propertyController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final provider = context.read<BusinessLogicProvider>();
      final selected = _providers.firstWhere(
          (p) => p.id == _selectedProviderId,
          orElse: () => ServiceProvider(id: '', name: ''));
      final created = await provider.createMaintenanceRequest(
          _propertyController.text, _descController.text,
          priority: _priority,
          assignedProviderId: selected.id.isEmpty ? null : selected.id,
          assignedProviderName: selected.id.isEmpty ? null : selected.name);
      if (created != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ticket created successfully')));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not create ticket')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Maintenance Ticket')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _propertyController,
                decoration: const InputDecoration(labelText: 'Property ID'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter property id' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter description' : null,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              // Provider assignment (optional)
              DropdownButtonFormField<String?>(
                value: _selectedProviderId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Auto-assign / None')),
                  ..._providers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList()
                ],
                onChanged: (v) => setState(() => _selectedProviderId = v),
                decoration: const InputDecoration(labelText: 'Assign Provider (optional)'),
                isExpanded: true,
              ),
              if (_providers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Text('No providers available — add providers in Real Estate settings', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _priority,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'medium'),
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const CircularProgressIndicator() : const Text('Create Ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

