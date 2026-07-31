import 'package:flutter/material.dart';

import '../../data/repositories/admin_repository.dart';
import '../admin_theme.dart';

class AdminWorkersPage extends StatefulWidget {
  const AdminWorkersPage({super.key});

  @override
  State<AdminWorkersPage> createState() => _AdminWorkersPageState();
}

class _AdminWorkersPageState extends State<AdminWorkersPage> {
  final _adminRepository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _workersFuture;

  static const _roles = [
    'Customer Support',
    'Programmer',
    'Tester',
    'Operations',
    'Admin',
  ];

  @override
  void initState() {
    super.initState();
    _workersFuture = _adminRepository.fetchInternalWorkers();
  }

  void _refreshWorkers() {
    setState(() {
      _workersFuture = _adminRepository.fetchInternalWorkers();
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
                          'ManageCare Workers',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.adminTextPrimary,
                          ),
                        ),
                        Text(
                          'Internal team accounts and role assignments',
                          style: TextStyle(color: context.adminTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showWorkerDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Worker'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _workersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load workers',
                        style: TextStyle(color: context.adminTextSecondary),
                      ),
                    );
                  }
                  final workers = snapshot.data ?? const [];
                  if (workers.isEmpty) {
                    return Center(
                      child: Text(
                        'No internal workers created yet',
                        style: TextStyle(color: context.adminTextSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: workers.length,
                    itemBuilder: (context, index) {
                      final worker = workers[index];
                      return _workerCard(worker['id'].toString(), worker);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workerCard(String id, Map<String, dynamic> data) {
    final active = data['isActive'] != false;
    final role = (data['role'] ?? 'Worker').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration:
          context.adminCardDecoration(borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                (active ? const Color(0xFF10B981) : const Color(0xFF64748B))
                    .withOpacity(0.12),
            child: Icon(
              role.toLowerCase().contains('programmer')
                  ? Icons.code_rounded
                  : Icons.support_agent_rounded,
              color: active
                  ? const Color(0xFF10B981)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['name'] ?? 'Worker').toString(),
                  style: TextStyle(
                    color: context.adminTextPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['email'] ?? ''} - $role',
                  style: TextStyle(color: context.adminTextSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            onChanged: (value) async {
              await _adminRepository.saveInternalWorker(
                {'isActive': value},
                id: id,
              );
              if (mounted) _refreshWorkers();
            },
          ),
          IconButton(
            onPressed: () => _showWorkerDialog(id: id, existing: data),
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
          ),
        ],
      ),
    );
  }

  Future<void> _showWorkerDialog({
    String? id,
    Map<String, dynamic>? existing,
  }) async {
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final emailController =
        TextEditingController(text: existing?['email']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: existing?['phone']?.toString() ?? '');
    final passwordController = TextEditingController();
    var obscurePassword = true;
    var selectedRole = existing?['role']?.toString() ?? _roles.first;
    var isActive = existing?['isActive'] != false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(id == null ? 'Create Worker' : 'Edit Worker'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: id == null
                        ? 'Leave blank to auto-generate'
                        : 'Leave blank to keep the current password',
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: _roles
                      .map((role) =>
                          DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedRole = value ?? _roles.first),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                SwitchListTile(
                  value: isActive,
                  onChanged: (value) =>
                      setDialogState(() => isActive = value),
                  title: const Text('Active'),
                  contentPadding: EdgeInsets.zero,
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
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter name and email')),
                  );
                  return;
                }
                var password = passwordController.text.trim();
                // Only auto-generate on create - leaving it blank on edit
                // means "don't change the password", not "set it to this".
                final generated = password.isEmpty && id == null;
                if (generated) {
                  password = 'Temp${DateTime.now().millisecondsSinceEpoch}'
                      .substring(0, 12);
                }
                final payload = {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'role': selectedRole,
                  'roleKey': selectedRole.toLowerCase().replaceAll(' ', '_'),
                  'isActive': isActive,
                  if (password.isNotEmpty) 'password': password,
                };
                await _adminRepository.saveInternalWorker(payload, id: id);
                if (!mounted) return;
                _refreshWorkers();
                Navigator.of(dialogContext).pop();
                if (generated) {
                  showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Worker created'),
                      content: SelectableText(
                        'Share this temporary password with ${nameController.text.trim()} - it will not be shown again:\n\n$password',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
