import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_admin/admin_theme.dart';
import '../../core/constants/routes.dart';
import '../../core/utils/datetime_utils.dart';
import '../../data/repositories/admin_repository.dart';

class InternalWorkerDashboardScreen extends StatefulWidget {
  const InternalWorkerDashboardScreen({super.key});

  @override
  State<InternalWorkerDashboardScreen> createState() =>
      _InternalWorkerDashboardScreenState();
}

class _InternalWorkerDashboardScreenState
    extends State<InternalWorkerDashboardScreen> {
  final _adminRepository = AdminRepository();
  late Future<_WorkerDashboardData> _dataFuture;

  static const _statuses = [
    ('pending', 'Pending Jobs'),
    ('review', 'Awaiting Admin Review'),
    ('done', 'Done'),
    ('returned', 'Returned'),
  ];

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_WorkerDashboardData> _loadData() async {
    final results = await Future.wait([
      _adminRepository.fetchMyWorkerProfile(),
      _adminRepository.fetchMyWorkItems(),
    ]);
    return _WorkerDashboardData(
      profile: results[0] as Map<String, dynamic>,
      workItems: results[1] as List<Map<String, dynamic>>,
    );
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _confirmFixed(String id) async {
    await _adminRepository.submitWorkItemForReview(id);
    if (mounted) _refresh();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.marketerLogin,
      (route) => false,
    );
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (value) => (value == null || value.length < 6)
                    ? 'At least 6 characters'
                    : null,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                await _adminRepository.changeMyWorkerPassword(
                  currentPassword: currentController.text.trim(),
                  newPassword: newController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated')),
                );
              } catch (_) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Could not update password'),
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.adminBackground,
      child: SafeArea(
        child: FutureBuilder<_WorkerDashboardData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Text(
                  'Unable to load your dashboard',
                  style: TextStyle(color: context.adminTextSecondary),
                ),
              );
            }
            final data = snapshot.data!;
            return Column(
              children: [
                _header(data.profile),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: _statuses.map((status) {
                      final items = data.workItems
                          .where((item) =>
                              (item['status'] ?? 'pending') == status.$1)
                          .toList();
                      return _statusSection(status.$1, status.$2, items);
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> profile) {
    final name = (profile['name'] ?? 'Worker').toString();
    final role = (profile['role'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF10B981).withOpacity(0.12),
            child: Icon(
              role.toLowerCase().contains('programmer')
                  ? Icons.code_rounded
                  : Icons.support_agent_rounded,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.adminTextPrimary,
                  ),
                ),
                Text(
                  role.isEmpty ? 'ManageCare Team' : role,
                  style: TextStyle(color: context.adminTextSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Change Password',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
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
            ...items.map((item) => _jobTile(status, item['id'].toString(), item)),
        ],
      ),
    );
  }

  Widget _jobTile(String status, String id, Map<String, dynamic> data) {
    final type = (data['type'] ?? 'fix').toString();
    final dueDate =
        data['dueDate'] == null ? null : parseTimestamp(data['dueDate']);
    final now = DateTime.now();
    final countdown = dueDate == null
        ? (data['priority'] ?? 'normal').toString().toUpperCase()
        : dueDate.isBefore(now)
            ? 'OVERDUE'
            : '${dueDate.difference(now).inDays} days left';
    final color =
        type == 'update' ? const Color(0xFF3B82F6) : const Color(0xFFF97316);

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
              if (dueDate != null)
                _chip(DateFormat('dd MMM yyyy').format(dueDate),
                    Icons.event_rounded),
            ],
          ),
          if (status == 'pending' || status == 'review') ...[
            const SizedBox(height: 10),
            if (status == 'pending')
              FilledButton.icon(
                onPressed: () => _confirmFixed(id),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Confirm Fixed'),
              )
            else
              _chip('Waiting on admin review', Icons.hourglass_top_rounded),
          ],
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
}

class _WorkerDashboardData {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> workItems;

  _WorkerDashboardData({required this.profile, required this.workItems});
}
