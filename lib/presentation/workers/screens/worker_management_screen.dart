import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../widgets/profile_avatar.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/business_provider.dart';
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
    final businessProvider = context.watch<BusinessProvider>();
    // final authProvider = context.watch<AuthProvider>();
    final businessType =
        businessProvider.currentBusiness?.businessType ?? 'retail';

    final availableRoles = WorkerPermissions.getAvailableRoles(businessType);

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
          _buildActiveWorkersTab(availableRoles),
          // Permissions Tab
          _buildPermissionsTab(availableRoles),
          // Performance Tab
          _buildPerformanceTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AddWorkerScreen(),
          ),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Worker'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActiveWorkersTab(List<String> availableRoles) {
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
                    .where((w) => _filterRoles.contains(w['role']))
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
                  final business =
                      Provider.of<BusinessProvider>(context, listen: false)
                          .currentBusiness;

                  return _buildWorkerCard(
                    workerId: workerId,
                    name: (worker['name'] ?? worker['fullName'] ?? 'Worker')
                        as String,
                    role: (worker['role'] as String?) ?? 'staff',
                    status:
                        (worker['isActive'] == true) ? 'Active' : 'Off-duty',
                    businessId: business?.id,
                    businessType: business?.businessType,
                    photoUrl: (worker['photoUrl'] ?? worker['photo_url']) as String?,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
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
                                Text(permission
                                    .replaceAll('_', ' ')
                                    .toUpperCase()),
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

  Widget _buildPerformanceTab() {
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
    required String workerId,
    required String name,
    required String role,
    required String status,
    String? businessId,
    String? businessType,
    String? photoUrl,
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
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    child: const Text('View Details'),
                    onTap: () => _navigateToWorkerDetails(
                        workerId, businessId, businessType),
                  ),
                  const PopupMenuItem(
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

  Future<List<Map<String, dynamic>>> _fetchWorkers() async {
    try {
      final business =
          Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      if (business == null) return <Map<String, dynamic>>[];

      // Get from workers collection
      final snap = await FirebaseFirestore.instance
          .collection('workers')
          .where('businessId', isEqualTo: business.id)
          .where('isActive', isEqualTo: true)
          .get();
      final List<Map<String, dynamic>> result = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList()
          .cast<Map<String, dynamic>>();

      // Also get from users collection
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('businessId', isEqualTo: business.id)
          .where('isOwner', isEqualTo: false)
          .get();
      final usersWorkers = usersSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList()
          .cast<Map<String, dynamic>>();

      // Merge and deduplicate
      final workerMap = <String, dynamic>{};
      for (var worker in result) {
        workerMap[worker['id']] = worker;
      }
      for (var worker in usersWorkers) {
        workerMap[worker['id']] = worker;
      }

      final merged = workerMap.values.toList().cast<Map<String, dynamic>>();

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
}

