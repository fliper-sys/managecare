import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';

class CreateServiceOrderScreen extends StatefulWidget {
  const CreateServiceOrderScreen({super.key});

  @override
  State<CreateServiceOrderScreen> createState() =>
      _CreateServiceOrderScreenState();
}

class _CreateServiceOrderScreenState extends State<CreateServiceOrderScreen> {
  String? _selectedVehicleId;
  final Set<String> _selectedServiceIds = {};
  final List<Part> _selectedParts = [];
  Part? _partToAdd;
  int _partQty = 1;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final auto = context.watch<AutoProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Service Order')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select Vehicle'),
              value: _selectedVehicleId,
              items: auto.vehicles
                  .map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.make} ${v.model} (${v.licensePlate})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedVehicleId = v),
            ),
            const SizedBox(height: 12),
            const Text('Services', style: TextStyle(fontWeight: FontWeight.bold)),
            ...auto.services.map((s) {
              final checked = _selectedServiceIds.contains(s.id);
              return CheckboxListTile(
                value: checked,
                title: Text('${s.name} (${formatCurrency(s.laborCost)})'),
                onChanged: (val) => setState(() => val == true ? _selectedServiceIds.add(s.id) : _selectedServiceIds.remove(s.id)),
              );
            }).toList(),
            const SizedBox(height: 8),
            const Text('Add Parts', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Part>(
                    decoration: const InputDecoration(labelText: 'Part'),
                    value: _partToAdd,
                    items: auto.parts
                        .map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (stock: ${p.quantity})')))
                        .toList(),
                    onChanged: (p) => setState(() => _partToAdd = p),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Qty'),
                    initialValue: '1',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _partQty = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _partToAdd == null
                      ? null
                      : () {
                          if (_partQty < 1) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be at least 1')));
                            return;
                          }
                          if (_partToAdd!.quantity < _partQty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough stock')));
                            return;
                          }
                          setState(() {
                            _selectedParts.add(Part(id: _partToAdd!.id, name: _partToAdd!.name, quantity: _partQty, cost: _partToAdd!.cost));
                          });
                        },
                  child: const Text('Add'),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedParts.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedParts.map((p) => Chip(label: Text('${p.name} x${p.quantity}'), onDeleted: () {
                      setState(() => _selectedParts.remove(p));
                    })).toList(),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                            if (_selectedVehicleId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a vehicle')));
                              return;
                            }
                            if (_selectedServiceIds.isEmpty && _selectedParts.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one service or part')));
                              return;
                            }
                            setState(() => _isSubmitting = true);
                            try {
                              final id = const Uuid().v4();
                              final tasks = auto.services.where((s) => _selectedServiceIds.contains(s.id)).toList();
                              final job = Job(
                                id: id,
                                vehicleId: _selectedVehicleId!,
                                createdAt: DateTime.now(),
                                tasks: tasks,
                                usedParts: _selectedParts.map((p) => Part(id: p.id, name: p.name, quantity: p.quantity, cost: p.cost)).toList(),
                                notes: _notesController.text,
                              );
                              auto.createJob(job);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service order created')));
                              Navigator.of(context).pop();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            } finally {
                              if (mounted) setState(() => _isSubmitting = false);
                            }
                          },
                    child: const Text('Create Service Order'),
                  ),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

