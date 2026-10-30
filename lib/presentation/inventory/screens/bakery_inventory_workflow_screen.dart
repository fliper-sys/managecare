import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/inventory_repository_supabase.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';

class BakeryInventoryWorkflowScreen extends StatefulWidget {
  const BakeryInventoryWorkflowScreen({super.key});

  @override
  State<BakeryInventoryWorkflowScreen> createState() =>
      _BakeryInventoryWorkflowScreenState();
}

class _BakeryInventoryWorkflowScreenState
    extends State<BakeryInventoryWorkflowScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final InventoryRepositorySupabase _repository =
      InventoryRepositorySupabase();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _pendingResupplies = [];
  List<Map<String, dynamic>> _pendingSpoilage = [];
  List<Map<String, dynamic>> _resupplyHistory = [];
  List<Map<String, dynamic>> _spoilageHistory = [];
  List<Map<String, dynamic>> _inventory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _businessId =>
      context.read<BusinessProvider>().currentBusiness?.id ?? '';

  bool get _canApprove {
    final user = context.read<AuthProvider>().currentUser;
    final role = user?.role.toLowerCase().trim() ?? '';
    return user?.isOwner == true ||
        const {'owner', 'admin', 'sub_admin', 'manager'}.contains(role);
  }

  Future<void> _load() async {
    if (_businessId.isEmpty) {
      setState(() {
        _error = 'No business selected';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _repository.fetchBakeryResupplies(
          businessId: _businessId,
          status: 'pending',
        ),
        _repository.fetchBakerySpoilage(
          businessId: _businessId,
          status: 'pending',
        ),
        _repository.fetchBakeryResupplies(businessId: _businessId),
        _repository.fetchBakerySpoilage(businessId: _businessId),
        _repository.getInventory(_businessId),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingResupplies = values[0] as List<Map<String, dynamic>>;
        _pendingSpoilage = values[1] as List<Map<String, dynamic>>;
        _resupplyHistory = values[2] as List<Map<String, dynamic>>;
        _spoilageHistory = values[3] as List<Map<String, dynamic>>;
        _inventory = (values[4] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load bakery inventory requests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _decide({
    required String id,
    required bool spoilage,
    required String decision,
  }) async {
    try {
      if (spoilage) {
        await _repository.decideBakerySpoilage(
          businessId: _businessId,
          recordId: id,
          decision: decision,
        );
      } else {
        await _repository.decideBakeryResupply(
          businessId: _businessId,
          requestId: id,
          decision: decision,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(decision == 'approved'
            ? 'Request approved; inventory updated'
            : 'Request rejected'),
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not $decision request: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _editResupply(Map<String, dynamic> request) async {
    final productIdController =
        ValueNotifier<String>((request['inventoryId'] ?? '').toString());
    final quantityController =
        TextEditingController(text: '${request['quantity'] ?? 1}');
    final notesController =
        TextEditingController(text: (request['notes'] ?? '').toString());
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit pending resupply'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: productIdController,
                builder: (context, value, _) => DropdownButtonFormField<String>(
                  value: _inventory.any((item) => item['id']?.toString() == value)
                      ? value
                      : null,
                  decoration: const InputDecoration(labelText: 'Inventory item'),
                  items: _inventory
                      .map((item) => DropdownMenuItem<String>(
                            value: item['id']?.toString(),
                            child: Text((item['name'] ?? 'Unnamed').toString()),
                          ))
                      .toList(),
                  onChanged: (next) {
                    if (next != null) productIdController.value = next;
                  },
                ),
              ),
              TextField(
                controller: quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (selected != 'save') return;
    final quantity = double.tryParse(quantityController.text.trim());
    final inventoryId = productIdController.value;
    productIdController.dispose();
    quantityController.dispose();
    notesController.dispose();
    if (inventoryId.isEmpty || quantity == null || quantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an item and enter a valid quantity')),
        );
      }
      return;
    }
    try {
      await _repository.updateBakeryResupply(
        businessId: _businessId,
        requestId: request['id'].toString(),
        inventoryId: inventoryId,
        quantity: quantity,
        bakerId: request['bakerId']?.toString(),
        bakerName: request['bakerName']?.toString(),
        notes: notesController.text.trim(),
        expectedProductionAmount:
            request['expectedProductionAmount'] as num? ?? 0,
        actualProductionAmount:
            request['actualProductionAmount'] as num? ?? 0,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pending resupply updated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to edit resupply: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _recordSpoilage() async {
    if (_inventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inventory products are available')),
      );
      return;
    }
    final productId = ValueNotifier<String?>(null);
    final quantity = TextEditingController(text: '1');
    final notes = TextEditingController();
    String reason = 'Damaged';
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report spoilage or damage'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: productId,
                  builder: (context, selected, _) =>
                      DropdownButtonFormField<String>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Inventory item'),
                    items: _inventory
                        .map((item) => DropdownMenuItem<String>(
                              value: item['id']?.toString(),
                              child: Text((item['name'] ?? 'Unnamed').toString()),
                            ))
                        .toList(),
                    onChanged: (value) => productId.value = value,
                  ),
                ),
                TextField(
                  controller: quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity affected'),
                ),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(value: 'Damaged', child: Text('Damaged')),
                    DropdownMenuItem(value: 'Spoiled', child: Text('Spoiled')),
                    DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                    DropdownMenuItem(value: 'Contaminated', child: Text('Contaminated')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Details (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit for approval'),
            ),
          ],
        ),
      ),
    );
    final selectedProductId = productId.value;
    final affectedQuantity = double.tryParse(quantity.text.trim());
    final details = notes.text.trim();
    productId.dispose();
    quantity.dispose();
    notes.dispose();
    if (submit != true) return;
    if (selectedProductId == null ||
        affectedQuantity == null ||
        affectedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an item and enter a valid quantity')),
      );
      return;
    }
    try {
      await _repository.createBakerySpoilage(
        businessId: _businessId,
        inventoryId: selectedProductId,
        quantity: affectedQuantity,
        reason: reason,
        notes: details,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spoilage submitted for approval')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to submit spoilage: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _recordCard(
    Map<String, dynamic> record, {
    required bool spoilage,
    required bool pending,
  }) {
    final status = (record['status'] ?? 'approved').toString();
    final qty = (record['quantity'] as num?)?.toDouble() ?? 0;
    final actions = <Widget>[];
    if (pending && spoilage && _canApprove) {
      actions.add(TextButton(
        onPressed: () => _decide(
          id: record['id'].toString(),
          spoilage: true,
          decision: 'rejected',
        ),
        child: const Text('Reject'),
      ));
      actions.add(FilledButton(
        onPressed: () => _decide(
          id: record['id'].toString(),
          spoilage: true,
          decision: 'approved',
        ),
        child: const Text('Approve'),
      ));
    } else if (pending && !spoilage) {
      actions.add(TextButton.icon(
        onPressed: () => _editResupply(record),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ));
      if (_canApprove) {
        actions.add(TextButton(
          onPressed: () => _decide(
            id: record['id'].toString(),
            spoilage: false,
            decision: 'rejected',
          ),
          child: const Text('Reject'),
        ));
        actions.add(FilledButton(
          onPressed: () => _decide(
            id: record['id'].toString(),
            spoilage: false,
            decision: 'approved',
          ),
          child: const Text('Approve'),
        ));
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (record['inventoryName'] ?? 'Inventory item').toString(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(status.toUpperCase())),
              ],
            ),
            Text('Quantity: ${qty.toStringAsFixed(2)} ${record['unit'] ?? ''}'),
            if (spoilage) Text('Reason: ${record['reason'] ?? ''}'),
            if (!spoilage && (record['bakerName'] ?? '').toString().isNotEmpty)
              Text('Assigned to: ${record['bakerName']}'),
            if ((record['notes'] ?? '').toString().isNotEmpty)
              Text('Notes: ${record['notes']}'),
            Text('Submitted: ${_date(record['createdAt'])}'),
            if (actions.isNotEmpty)
              Wrap(alignment: WrapAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _resolvedHistory(bool spoilage) {
    final records = spoilage ? _spoilageHistory : _resupplyHistory;
    return records
        .where((record) => record['status'] != 'pending')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakery inventory workflow'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'History'),
            Tab(text: 'Spoilage'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (_pendingResupplies.isEmpty &&
                              _pendingSpoilage.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('No requests awaiting approval'),
                              ),
                            ),
                          ..._pendingResupplies.map((record) => _recordCard(
                                record,
                                spoilage: false,
                                pending: true,
                              )),
                          ..._pendingSpoilage.map((record) => _recordCard(
                                record,
                                spoilage: true,
                                pending: true,
                              )),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          const Text('Resupply decisions'),
                          ..._resolvedHistory(false).map((record) => _recordCard(
                                record,
                                spoilage: false,
                                pending: false,
                              )),
                          const SizedBox(height: 12),
                          const Text('Spoilage decisions'),
                          ..._resolvedHistory(true).map((record) => _recordCard(
                                record,
                                spoilage: true,
                                pending: false,
                              )),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _recordSpoilage,
                              icon: const Icon(Icons.report_problem_outlined),
                              label: const Text('Record spoilage or damage'),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              children: _spoilageHistory
                                  .map((record) => _recordCard(
                                        record,
                                        spoilage: true,
                                        pending: record['status'] == 'pending',
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
