import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';
import '../../../../providers/customer_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/workers_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import 'create_vehicle_screen.dart';

class CreateServiceOrderScreen extends StatefulWidget {
  const CreateServiceOrderScreen({super.key});

  @override
  State<CreateServiceOrderScreen> createState() =>
      _CreateServiceOrderScreenState();
}

class _CreateServiceOrderScreenState extends State<CreateServiceOrderScreen> {
  String? _selectedVehicleId;
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedWorkerId;
  String? _selectedWorkerName;
  double? _selectedWorkerCommission;
  final Set<String> _selectedServiceIds = {};
  final List<Part> _selectedParts = [];
  Part? _partToAdd;
  int _partQty = 1;
  final TextEditingController _workDescriptionController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  bool _workerMatchesAutoRoles(Map<String, dynamic> worker) {
    final autoRoles = WorkerPermissions.getAvailableRoles('auto')
        .map(WorkerPermissions.normalizeRole)
        .toSet();
    final roles = <String>{};
    final primaryRole = worker['role']?.toString();
    if (primaryRole != null && primaryRole.trim().isNotEmpty) {
      roles.add(WorkerPermissions.normalizeRole(primaryRole));
    }
    final secondaryRoles = worker['roles'];
    if (secondaryRoles is List) {
      for (final role in secondaryRoles) {
        final normalized = WorkerPermissions.normalizeRole(role.toString());
        if (normalized.isNotEmpty) {
          roles.add(normalized);
        }
      }
    }
    return roles.any(autoRoles.contains);
  }

  String _workerDisplayLabel(Map<String, dynamic> worker) {
    final name = (worker['fullName'] ?? worker['name'] ?? 'Worker').toString();
    final rawRole = (worker['role'] ?? '').toString().trim();
    final roleLabel = rawRole.isEmpty
        ? ''
        : ' • ${WorkerPermissions.getRoleDisplayName(rawRole)}';
    return '$name$roleLabel';
  }

  String _workerRoleHint(Map<String, dynamic> worker) {
    final role = (worker['role'] ?? '').toString().trim();
    if (role.isEmpty) return 'Available for workshop assignment';
    final description = WorkerPermissions.getRoleDescription(role);
    return description.isEmpty
        ? WorkerPermissions.getRoleDisplayName(role)
        : description;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final businessId =
          context.read<BusinessProvider>().currentBusiness?.id ?? '';
      if (businessId.isNotEmpty) {
        try {
          context.read<WorkersProvider>().refreshForBusiness(businessId);
        } catch (_) {}
        try {
          context.read<CustomerProvider>().loadCustomers();
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auto = context.watch<AutoProvider>();
    final workersProvider = context.watch<WorkersProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final workers = workersProvider.workers.toList()
      ..sort((left, right) {
        final leftPreferred = _workerMatchesAutoRoles(left) ? 0 : 1;
        final rightPreferred = _workerMatchesAutoRoles(right) ? 0 : 1;
        if (leftPreferred != rightPreferred) return leftPreferred - rightPreferred;
        final leftName = (left['fullName'] ?? left['name'] ?? '').toString();
        final rightName = (right['fullName'] ?? right['name'] ?? '').toString();
        return leftName.toLowerCase().compareTo(rightName.toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Create Service Order')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Select Customer (optional)'),
                value: _selectedCustomerId,
                items: customerProvider.customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer.id,
                        child: Text(
                          customer.phone?.isNotEmpty == true
                              ? '${customer.name} • ${customer.phone}'
                              : customer.name,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (customerId) {
                  final selected = customerProvider.customers
                      .where((customer) => customer.id == (customerId ?? ''))
                      .toList();
                  setState(() {
                    _selectedCustomerId = customerId;
                    _selectedCustomerName = selected.isEmpty ? null : selected.first.name;
                    final availableVehicleIds = (customerId == null
                            ? auto.vehicles
                            : auto.getVehiclesForCustomer(customerId))
                        .map((v) => v.id)
                        .toSet();
                    if (_selectedVehicleId != null &&
                        !availableVehicleIds.contains(_selectedVehicleId)) {
                      _selectedVehicleId = null;
                    }
                  });
                },
              ),
              if (_selectedCustomerName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Customer: $_selectedCustomerName',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final customerVehicles = _selectedCustomerId == null
                    ? auto.vehicles
                    : auto.getVehiclesForCustomer(_selectedCustomerId!);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: _selectedCustomerId == null
                            ? 'Select Vehicle'
                            : "Select ${_selectedCustomerName ?? 'Customer'}'s Vehicle",
                      ),
                      value: _selectedVehicleId,
                      items: customerVehicles
                          .map(
                            (v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                '${v.make} ${v.model} (${v.licensePlate})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedVehicleId = v),
                    ),
                    if (_selectedCustomerId != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<Vehicle>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateVehicleScreen(
                                customerId: _selectedCustomerId,
                                customerName: _selectedCustomerName,
                              ),
                            ),
                          );
                          if (result != null) {
                            setState(() => _selectedVehicleId = result.id);
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: Text(
                          customerVehicles.isEmpty
                              ? 'Add a car for ${_selectedCustomerName ?? 'this customer'}'
                              : 'Add another car for ${_selectedCustomerName ?? 'this customer'}',
                        ),
                      ),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Assign Worker (optional)'),
                value: _selectedWorkerId,
                items: workers
                    .map(
                      (worker) => DropdownMenuItem(
                        value: (worker['id'] ?? '').toString(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(_workerDisplayLabel(worker))),
                                if (_workerMatchesAutoRoles(worker))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Auto',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _workerRoleHint(worker),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (workerId) {
                  final selected = workers.cast<Map<String, dynamic>>().firstWhere(
                        (worker) => (worker['id'] ?? '').toString() == (workerId ?? ''),
                        orElse: () => const <String, dynamic>{},
                      );
                  setState(() {
                    _selectedWorkerId = workerId;
                    _selectedWorkerName = selected.isEmpty
                        ? null
                        : (selected['fullName'] ?? selected['name'] ?? '')
                            .toString();
                    _selectedWorkerCommission = selected.isEmpty
                        ? null
                        : (selected['commissionPercentage'] as num?)?.toDouble();
                  });
                },
              ),
              if (_selectedWorkerName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Assigned to: $_selectedWorkerName',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _workDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Job Description',
                  hintText: 'Describe the work to be done',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              if (_selectedWorkerId != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.percent, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (_selectedWorkerCommission == null ||
                                  _selectedWorkerCommission == 0)
                              ? 'No bonus % set for $_selectedWorkerName. '
                                  'Set it from Worker Management to give this worker a Workmanship bonus.'
                              : 'Workmanship bonus: ${_selectedWorkerCommission!.toStringAsFixed(1)}% '
                                  'of this job (set by admin for $_selectedWorkerName).',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Services',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...auto.services.map((s) {
                final checked = _selectedServiceIds.contains(s.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text('${s.name} (${formatCurrency(s.laborCost)})'),
                  onChanged: (val) => setState(() {
                    if (val == true) {
                      _selectedServiceIds.add(s.id);
                    } else {
                      _selectedServiceIds.remove(s.id);
                    }
                  }),
                );
              }),
              const SizedBox(height: 8),
              const Text('Add Parts',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Part>(
                      decoration: const InputDecoration(labelText: 'Part'),
                      value: _partToAdd,
                      items: auto.parts
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text('${p.name} (stock: ${p.quantity})'),
                            ),
                          )
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Quantity must be at least 1'),
                                ),
                              );
                              return;
                            }
                            if (_partToAdd!.quantity < _partQty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Not enough stock')),
                              );
                              return;
                            }
                            setState(() {
                              _selectedParts.add(
                                Part(
                                  id: _partToAdd!.id,
                                  name: _partToAdd!.name,
                                  quantity: _partQty,
                                  cost: _partToAdd!.cost,
                                ),
                              );
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
                  children: _selectedParts
                      .map(
                        (p) => Chip(
                          label: Text('${p.name} x${p.quantity}'),
                          onDeleted: () {
                            setState(() => _selectedParts.remove(p));
                          },
                        ),
                      )
                      .toList(),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Select a vehicle')),
                            );
                            return;
                          }
                          if (_selectedServiceIds.isEmpty &&
                              _selectedParts.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Add at least one service or part'),
                              ),
                            );
                            return;
                          }
                          setState(() => _isSubmitting = true);
                          try {
                            final id = const Uuid().v4();
                            final tasks = auto.services
                                .where((s) => _selectedServiceIds.contains(s.id))
                                .toList();
                            final estimatedTotal = tasks.fold<double>(
                                  0.0,
                                  (sum, task) => sum + task.laborCost,
                                ) +
                                _selectedParts.fold<double>(
                                  0.0,
                                  (sum, part) =>
                                      sum + (part.cost * part.quantity),
                                );
                            final workmanshipRate =
                                _selectedWorkerCommission ?? 0.0;
                            final workmanshipAmount =
                                estimatedTotal * (workmanshipRate / 100);
                              final job = Job(
                              id: id,
                              vehicleId: _selectedVehicleId!,
                              customerId: _selectedCustomerId,
                              assignedWorkerId: _selectedWorkerId,
                              assignedWorkerName: _selectedWorkerName,
                              description: _workDescriptionController.text.trim(),
                              workmanshipRate: workmanshipRate,
                              workmanshipAmount: workmanshipAmount,
                              createdAt: DateTime.now(),
                              tasks: tasks,
                              usedParts: _selectedParts
                                  .map(
                                    (p) => Part(
                                      id: p.id,
                                      name: p.name,
                                      quantity: p.quantity,
                                      cost: p.cost,
                                    ),
                                  )
                                  .toList(),
                              notes: _notesController.text,
                            );
                            await auto.createJob(job);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Service order created'),
                              ),
                            );
                            Navigator.of(context).pop();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isSubmitting = false);
                            }
                          }
                        },
                  child: const Text('Create Service Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _workDescriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
