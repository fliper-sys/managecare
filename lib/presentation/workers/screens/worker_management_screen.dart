import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../data/repositories/worker_repository_impl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/workers_provider.dart';
import '../../../widgets/profile_avatar.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auto_provider.dart';
import '../../../core/utils/currency.dart';
import 'add_worker_screen.dart';
import 'worker_details_screen.dart';

class WorkerManagementScreen extends StatefulWidget {
  const WorkerManagementScreen({super.key});

  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _filterRoles = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final businessType =
        businessProvider.currentBusiness?.businessType ?? 'retail';

    final availableRoles = WorkerPermissions.getAvailableRoles(businessType);
    final canManageStaff = authProvider.currentUser != null &&
        WorkerPermissions.canManageStaffForUser(
          authProvider.currentUser!.role,
          authProvider.currentUser!.permissions,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Management'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Workers'),
            Tab(text: 'Permissions'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Workers Tab
          _buildActiveWorkersTab(availableRoles, canManageStaff),
          // Permissions Tab
          _buildPermissionsTab(availableRoles),
          // Performance Tab
          _buildPerformanceTab(businessType),
        ],
      ),
      floatingActionButton: canManageStaff
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddWorkerScreen(),
                ),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Worker'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildActiveWorkersTab(
    List<String> availableRoles,
    bool canManageStaff,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search workers by name or email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filter by Role',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: availableRoles
                      .map((role) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                  WorkerPermissions.getRoleDisplayName(role)),
                              selected: _filterRoles.contains(role),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _filterRoles.add(role);
                                  } else {
                                    _filterRoles.remove(role);
                                  }
                                });
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchWorkers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var workers = snapshot.data ?? [];

              // Apply role filter
              if (_filterRoles.isNotEmpty) {
                workers = workers
                    .where((w) {
                      final workerRoles = _workerRoles(w);
                      return workerRoles.any(_filterRoles.contains);
                    })
                    .toList();
              }

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                workers = workers.where((w) {
                  final name = ((w['name'] ?? w['fullName'] ?? '') as String)
                      .toLowerCase();
                  final email = ((w['email'] ?? '') as String).toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();
              }

              if (workers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty || _filterRoles.isNotEmpty
                            ? 'No workers match your search'
                            : 'No workers found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  final workerId = worker['id'] as String? ?? '';
                  final workerRoles = _workerRoles(worker);
                  final business =
                      Provider.of<BusinessProvider>(context, listen: false)
                          .currentBusiness;

                  return _buildWorkerCard(
                    worker: worker,
                    workerId: workerId,
                    name: (worker['name'] ?? worker['fullName'] ?? 'Worker')
                        as String,
                    email: (worker['email'] as String?)?.trim(),
                    role: workerRoles.isNotEmpty
                        ? workerRoles.first
                        : (worker['role'] as String?) ?? 'staff',
                    roles: workerRoles,
                    status:
                        (worker['isActive'] == true) ? 'Active' : 'Off-duty',
                    businessId: business?.id,
                    businessType: business?.businessType,
                    photoUrl: (worker['photoUrl'] ?? worker['photo_url']) as String?,
                    canManageStaff: canManageStaff,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<String> _workerRoles(Map<String, dynamic> worker) {
    final roles = (worker['roles'] as List<dynamic>?)?.cast<String>() ?? const [];
    if (roles.isNotEmpty) {
      return roles;
    }
    final primaryRole = (worker['role'] as String?)?.trim() ?? '';
    return primaryRole.isEmpty ? const ['staff'] : [primaryRole];
  }

  Widget _buildPermissionsTab(List<String> availableRoles) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: availableRoles.length,
      itemBuilder: (context, index) {
        final role = availableRoles[index];
        final permissions = WorkerPermissions.getPermissionsForRole(role);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              WorkerPermissions.getRoleDisplayName(role),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${permissions.length} permissions'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: permissions
                      .map((permission) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(WorkerPermissions.getPermissionLabel(permission)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceTab(String businessType) {
    final normalizedType = businessType.toLowerCase();
    if (normalizedType == 'auto' ||
        normalizedType == 'autorepair' ||
        normalizedType == 'auto_repair' ||
        normalizedType == 'automotive') {
      return _buildAutoPerformanceTab();
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPerformanceCard(
          'Top Performers',
          [
            _buildPerformanceItem('Worker 1', 150, 'sales'),
            _buildPerformanceItem('Worker 2', 120, 'sales'),
            _buildPerformanceItem('Worker 3', 95, 'sales'),
          ],
        ),
        const SizedBox(height: 16),
        _buildPerformanceCard(
          'Attendance Rate',
          [
            _buildPerformanceItem('Worker 1', 98, 'attendance'),
            _buildPerformanceItem('Worker 2', 95, 'attendance'),
            _buildPerformanceItem('Worker 3', 92, 'attendance'),
          ],
        ),
      ],
    );
  }

  /// Real performance data for auto service workers: completion rate,
  /// efficiency, and earnings sourced from AutoProvider's job records.
  Widget _buildAutoPerformanceTab() {
    const shopFloorRoles = {
      'mechanic',
      'electrician',
      'body_technician',
      'painter',
      'vulcanizer',
    };

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchWorkers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final shopWorkers = (snapshot.data ?? []).where((w) {
          final role = WorkerPermissions.normalizeRole(
              (w['role'] as String?)?.toLowerCase() ?? '');
          if (shopFloorRoles.contains(role)) return true;
          final roles = (w['roles'] as List<dynamic>?)
                  ?.map((r) =>
                      WorkerPermissions.normalizeRole(r.toString().toLowerCase()))
                  .toSet() ??
              {};
          return roles.any(shopFloorRoles.contains);
        }).toList();

        if (shopWorkers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.build_circle_outlined,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No mechanics, technicians, or other shop floor workers yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final autoProvider = context.watch<AutoProvider>();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: shopWorkers.length,
          itemBuilder: (context, index) {
            final worker = shopWorkers[index];
            final workerId = worker['id'] as String? ?? '';
            final name =
                (worker['name'] ?? worker['fullName'] ?? 'Worker') as String;
            final role = (worker['role'] as String?) ?? 'staff';

            final jobCount = autoProvider.getJobsForWorker(workerId).length;
            final completionRate =
                autoProvider.getWorkerCompletionRate(workerId);
            final efficiency = autoProvider.getWorkerEfficiency(workerId);
            final totalEarnings = autoProvider.getWorkerEarnings(workerId);
            final approvedEarnings =
                autoProvider.getWorkerApprovedEarnings(workerId);
            final pendingEarnings =
                autoProvider.getWorkerPendingEarnings(workerId);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ProfileAvatar(
                          photoUrl: (worker['photoUrl'] ?? worker['photo_url'])
                              as String?,
                          initials: name.isNotEmpty ? name[0] : '?',
                          backgroundColor: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${WorkerPermissions.getRoleDisplayName(role)} • $jobCount job${jobCount == 1 ? '' : 's'} assigned',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _AutoPerformanceStat(
                            label: 'Completion Rate',
                            value: '${completionRate.toStringAsFixed(0)}%',
                            icon: Icons.task_alt,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AutoPerformanceStat(
                            label: 'Efficiency',
                            value: '${efficiency.toStringAsFixed(0)}%',
                            icon: Icons.speed,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AutoPerformanceStat(
                            label: 'Total Earnings',
                            value: formatCurrency(totalEarnings),
                            icon: Icons.payments_outlined,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Approved ${formatCurrency(approvedEarnings)} • Pending ${formatCurrency(pendingEarnings)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceCard(String title, List<Widget> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(String name, int value, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(
            '$value ${type == 'sales' ? 'transactions' : '%'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard({
    required Map<String, dynamic> worker,
    required String workerId,
    required String name,
    String? email,
    required String role,
    List<String> roles = const [],
    required String status,
    String? businessId,
    String? businessType,
    String? photoUrl,
    required bool canManageStaff,
  }) {
    final isActive = status == 'Active';
    return Card(
      child: InkWell(
        onTap: () =>
            _navigateToWorkerDetails(workerId, businessId, businessType),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProfileAvatar(
                photoUrl: photoUrl,
                initials: name.isNotEmpty ? name[0] : '?',
                backgroundColor: isActive ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      WorkerPermissions.getRoleDisplayName(role),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (roles.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          roles
                              .map(WorkerPermissions.getRoleDisplayName)
                              .join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Chip(
                label: Text(status),
                backgroundColor: isActive
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isActive ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              if (canManageStaff)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        final currentPermissions =
                            ((worker['permissions'] ?? worker['customPermissions'])
                                        as List<dynamic>?)
                                    ?.map((permission) => permission.toString())
                                    .where((permission) =>
                                        permission !=
                                        WorkerPermissions
                                            .permissionOverrideMarker)
                                    .where((permission) =>
                                        permission.trim().isNotEmpty)
                                    .toList() ??
                                WorkerPermissions.getPermissionsForRole(role);
                        _showEditWorkerDialog(
                          workerId,
                          name,
                          role,
                          businessId,
                          currentPermissions,
                          (worker['terminalUserId'] ??
                                  worker['deviceUserId'] ??
                                  worker['attendanceDeviceUserId'] ??
                                  '')
                              .toString(),
                        );
                        break;
                      case 'view_details':
                        _navigateToWorkerDetails(
                          workerId,
                          businessId,
                          businessType,
                        );
                        break;
                      case 'reset_password':
                        _sendPasswordResetEmail(email);
                        break;
                      case 'remove':
                        _showRemoveWorkerDialog(workerId, name, businessId);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Permissions'),
                    ),
                    const PopupMenuItem(
                      value: 'view_details',
                      child: Text('View Details'),
                    ),
                    const PopupMenuItem(
                      value: 'reset_password',
                      child: Text('Reset Password'),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToWorkerDetails(
      String workerId, String? businessId, String? businessType) {
    print(
        '[WorkerMgmt] Navigating to worker details: workerId=$workerId, businessId=$businessId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkerDetailsScreen(
          workerId: workerId,
          businessId: businessId,
          businessType: businessType,
        ),
      ),
    );
  }

  Future<void> _sendPasswordResetEmail(String? email) async {
    final workerEmail = email?.trim() ?? '';
    if (workerEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker email is missing')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Worker Password'),
        content: Text(
          'A password reset email will be sent to $workerEmail. '
          'The worker can use it to create a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthRepositoryImpl(
        firebaseAuth: FirebaseAuth.instance,
      ).resetPassword(workerEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $workerEmail')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send password reset email: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWorkers() async {
    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business == null) return <Map<String, dynamic>>[];

      final repo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
      final merged = (await repo.getWorkers(business.id))
          .cast<Map<String, dynamic>>()
          .map((worker) => Map<String, dynamic>.from(worker))
          .toList();

      // Sort by name client-side
      merged.sort((a, b) {
        final aName = (a['name'] ?? a['fullName'] ?? '') as String;
        final bName = (b['name'] ?? b['fullName'] ?? '') as String;
        return aName.compareTo(bName);
      });

      return merged;
    } catch (e) {
      print('[WorkerMgmt] Error fetching workers: $e');
      return <Map<String, dynamic>>[];
    }
  }

  bool _isAdminScreenPermission(String permission) {
    return permission.startsWith('access_') ||
        permission == 'view_reports' ||
        permission == 'procurement_management' ||
        permission == 'manage_staff' ||
        permission == 'payroll_view';
  }

  void _showEditWorkerDialog(
    String workerId,
    String name,
    String currentRole,
    String? businessId,
    List<String> currentPermissions,
    String currentTerminalUserId,
  ) {
    final businessProvider = context.read<BusinessProvider>();
    final businessType = businessProvider.currentBusiness?.businessType ?? 'retail';
    final availableRoles = WorkerPermissions.getAvailableRoles(businessType);

    String selectedRole = currentRole;
    final terminalUserIdController =
        TextEditingController(text: currentTerminalUserId);
    final permissionOptions = <String>{
      ...WorkerPermissions.getPermissionsForRole(selectedRole),
      ...WorkerPermissions.getAdminGrantablePermissions(),
    }.toList()
      ..sort((a, b) => WorkerPermissions.getPermissionLabel(a)
          .compareTo(WorkerPermissions.getPermissionLabel(b)));
    final selectedPermissions = <String>{
      ...currentPermissions,
      if (currentPermissions.isEmpty)
        ...WorkerPermissions.getPermissionsForRole(selectedRole),
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Permissions for $name'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Role'),
                  ),
                  const SizedBox(height: 8),
                  ...availableRoles.map((role) => RadioListTile<String>(
                        title: Text(WorkerPermissions.getRoleDisplayName(role)),
                        value: role,
                        groupValue: selectedRole,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedRole = value;
                            selectedPermissions
                              ..clear()
                              ..addAll(
                                WorkerPermissions.getPermissionsForRole(value),
                              );
                            permissionOptions
                              ..clear()
                              ..addAll({
                                ...WorkerPermissions.getPermissionsForRole(
                                  selectedRole,
                                ),
                                ...WorkerPermissions
                                    .getAdminGrantablePermissions(),
                              })
                              ..sort((a, b) =>
                                  WorkerPermissions.getPermissionLabel(a)
                                      .compareTo(
                                WorkerPermissions.getPermissionLabel(b),
                              ));
                          });
                        },
                      )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: terminalUserIdController,
                    decoration: const InputDecoration(
                      labelText: 'Attendance terminal user ID',
                      helperText:
                          'Must match the user ID enrolled on the F16 device.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selectable permissions',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tick the admin screens this worker can open. Untick any permission to remove it immediately after saving.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  ...permissionOptions.map(
                    (permission) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        WorkerPermissions.getPermissionLabel(permission),
                      ),
                      subtitle: _isAdminScreenPermission(permission)
                          ? const Text('Admin screen access')
                          : null,
                      value: selectedPermissions.contains(permission),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedPermissions.add(permission);
                          } else {
                            selectedPermissions.remove(permission);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _updateWorkerRole(
                  workerId,
                  selectedRole,
                  businessId,
                  selectedPermissions.toList()..sort(),
                  terminalUserIdController.text.trim(),
                );
                Navigator.of(context).pop();
                this.setState(() {}); // Refresh the list
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateWorkerRole(
    String workerId,
    String newRole,
    String? businessId,
    List<String> permissions,
    String terminalUserId,
  ) async {
    try {
      final savedPermissions = <String>{
        WorkerPermissions.permissionOverrideMarker,
        ...permissions.where((permission) =>
            permission != WorkerPermissions.permissionOverrideMarker),
      }.toList()
        ..sort();
      final updateData = {
        'role': newRole,
        'roles': [newRole],
        'permissions': savedPermissions,
        'customPermissions': savedPermissions,
        'terminalUserId': terminalUserId,
        'deviceUserId': terminalUserId,
        'attendanceDeviceUserId': terminalUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Keep both mirrors aligned; SetOptions avoids failing if one doc is absent.
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .set(updateData, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(workerId)
          .set(updateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker permissions updated in real time')),
        );
      }
    } catch (e) {
      print('[WorkerMgmt] Error updating worker role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating role: $e')),
        );
      }
    }
  }

  void _showRemoveWorkerDialog(String workerId, String name, String? businessId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Worker'),
        content: Text('Are you sure you want to remove $name from this business?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _removeWorker(workerId, businessId);
              Navigator.of(context).pop();
              setState(() {}); // Refresh the list
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeWorker(String workerId, String? businessId) async {
    try {
      final targetBusinessId = businessId?.trim() ?? '';
      if (targetBusinessId.isNotEmpty) {
        await context.read<WorkersProvider>().removeWorkerFromBusiness(
              workerId,
              businessId: targetBusinessId,
            );
        await context.read<BusinessProvider>().refreshBusinessStats(targetBusinessId);
      } else {
        throw StateError('Business context is missing for this worker.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Worker removed successfully')),
        );
      }
    } catch (e) {
      print('[WorkerMgmt] Error removing worker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing worker: $e')),
        );
      }
    }
  }
}

class _AutoPerformanceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AutoPerformanceStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

