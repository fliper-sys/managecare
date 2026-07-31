import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/datetime_utils.dart';
import '../../data/repositories/admin_repository.dart';
import '../admin_theme.dart';

class AdminWorkPage extends StatefulWidget {
  const AdminWorkPage({super.key});

  @override
  State<AdminWorkPage> createState() => _AdminWorkPageState();
}

class _AdminWorkPageState extends State<AdminWorkPage> {
  final _adminRepository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _workItemsFuture;

  static const _statuses = [
    ('pending', 'Pending Jobs'),
    ('review', 'Completed Awaiting Testing'),
    ('done', 'Reviewed Done'),
    ('returned', 'Returned Jobs'),
  ];

  @override
  void initState() {
    super.initState();
    _workItemsFuture = _adminRepository.fetchWorkItems();
  }

  void _refreshWorkItems() {
    setState(() {
      _workItemsFuture = _adminRepository.fetchWorkItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.adminTextPrimary,
                          ),
                        ),
                        Text(
                          'Fixes and updates assigned to programmers',
                          style: TextStyle(color: context.adminTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showJobDialog,
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Job'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _workItemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load work items',
                        style: TextStyle(color: context.adminTextSecondary),
                      ),
                    );
                  }
                  final workItems = snapshot.data ?? const [];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: _statuses.map((status) {
                      final items = workItems
                          .where((item) =>
                              (item['status'] ?? 'pending') == status.$1)
                          .toList();
                      return _statusSection(status.$1, status.$2, items);
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusSection(
    String status,
    String title,
    List<Map<String, dynamic>> items,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration:
          context.adminCardDecoration(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.adminTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${items.length}',
                style: TextStyle(color: context.adminTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'No jobs here',
              style: TextStyle(color: context.adminTextTertiary),
            )
          else
            ...items.map((item) => _jobTile(item['id'].toString(), item)),
        ],
      ),
    );
  }

  Widget _jobTile(String id, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString();
    final type = (data['type'] ?? 'fix').toString();
    final dueDate =
        data['dueDate'] == null ? null : parseTimestamp(data['dueDate']);
    final now = DateTime.now();
    final countdown = dueDate == null
        ? (data['priority'] ?? 'normal').toString().toUpperCase()
        : dueDate.isBefore(now)
            ? 'OVERDUE'
            : '${dueDate.difference(now).inDays} days left';
    final color = type == 'update'
        ? const Color(0xFF3B82F6)
        : const Color(0xFFF97316);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.adminSurfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (data['title'] ?? 'Untitled job').toString(),
                  style: TextStyle(
                    color: context.adminTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (data['description'] ?? '').toString(),
            style: TextStyle(color: context.adminTextSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(countdown, Icons.timer_rounded),
              if ((data['assignedTo'] ?? '').toString().isNotEmpty)
                _chip(data['assignedTo'].toString(), Icons.person_rounded),
              if (dueDate != null)
                _chip(DateFormat('dd MMM yyyy').format(dueDate),
                    Icons.event_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'pending')
                FilledButton.icon(
                  onPressed: () => _setStatus(id, 'review'),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Confirm Fixed'),
                ),
              if (status == 'review') ...[
                FilledButton.icon(
                  onPressed: () => _setStatus(id, 'done'),
                  icon: const Icon(Icons.verified_rounded, size: 16),
                  label: const Text('Mark Done'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _setStatus(id, 'returned'),
                  icon: const Icon(Icons.assignment_return_rounded, size: 16),
                  label: const Text('Return'),
                ),
              ],
              if (status == 'returned')
                FilledButton.icon(
                  onPressed: () => _setStatus(id, 'pending'),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Reopen'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.adminSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.adminBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.adminTextSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: context.adminTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setStatus(String id, String status) async {
    await _adminRepository.updateWorkItemStatus(id, status);
    if (mounted) _refreshWorkItems();
  }

  Future<void> _showJobDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var type = 'fix';
    var priority = 'normal';
    DateTime? dueDate;
    Map<String, dynamic>? selectedWorker;
    final workersFuture = _adminRepository.fetchInternalWorkers();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Work Job'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: workersFuture,
                  builder: (context, snapshot) {
                    final workers = (snapshot.data ?? const [])
                        .where((worker) => worker['isActive'] != false)
                        .toList();
                    return DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: selectedWorker,
                      items: workers
                          .map((worker) => DropdownMenuItem(
                                value: worker,
                                child: Text(
                                  '${worker['name'] ?? 'Worker'} - ${worker['role'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedWorker = value),
                      decoration: InputDecoration(
                        labelText: 'Assigned to',
                        hintText: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? 'Loading workers...'
                            : 'Select a worker',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fix', label: Text('Fix')),
                    ButtonSegment(value: 'update', label: Text('Update')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) =>
                      setDialogState(() => type = value.first),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? 'normal'),
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dueDate == null
                            ? 'No countdown'
                            : DateFormat('dd MMM yyyy').format(dueDate!),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                          initialDate:
                              dueDate ?? DateTime.now().add(const Duration(days: 7)),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.timer_rounded),
                      label: const Text('Timeline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter title and message')),
                  );
                  return;
                }
                await _adminRepository.createWorkItem({
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  if (selectedWorker != null) ...{
                    'assignedTo': (selectedWorker!['name'] ?? '').toString(),
                    'assignedToWorkerId': selectedWorker!['id'],
                  },
                  'type': type,
                  'priority': priority,
                  'status': 'pending',
                  'dueDate': dueDate?.toIso8601String(),
                });
                if (!mounted) return;
                _refreshWorkItems();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
