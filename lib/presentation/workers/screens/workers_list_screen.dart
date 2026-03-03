import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/workers_provider.dart';
import '../../../providers/business_provider.dart';
import '../widgets/worker_card.dart';
import 'worker_management_screen.dart';
import 'worker_leaderboard_screen.dart';

class WorkersListScreen extends StatefulWidget {
  const WorkersListScreen({super.key});

  @override
  State<WorkersListScreen> createState() => _WorkersListScreenState();
}

class _WorkersListScreenState extends State<WorkersListScreen> {
  String _filterRole = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh workers list when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final businessProvider = context.read<BusinessProvider>();
      final workersProvider = context.read<WorkersProvider>();
      final businessId = businessProvider.currentBusiness?.id ?? '';
      if (businessId.isNotEmpty) {
        workersProvider.refreshForBusiness(businessId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isOwner = authProvider.currentUser?.isOwner ?? false;
    final businessProvider = context.watch<BusinessProvider>();
    final workersProvider = context.watch<WorkersProvider>();
    final businessId = businessProvider.currentBusiness?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workers'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Worker Leaderboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkerLeaderboardScreen(),
                ),
              );
            },
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.group_add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkerManagementScreen(),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search workers...',
                    onChanged: (query) {
                      // Filter logic can be implemented here if needed
                    },
                    leading: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(width: 12),
                if (isOwner)
                  PopupMenuButton<String>(
                    initialValue: _filterRole,
                    onSelected: (value) {
                      setState(() => _filterRole = value);
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'All',
                        child: Text('All Roles'),
                      ),
                      ...WorkerPermissions.getAvailableRoles('retail')
                          .map((role) => PopupMenuItem(
                                value: role,
                                child: Text(
                                    WorkerPermissions.getRoleDisplayName(role)),
                              )),
                    ],
                    child: const Icon(Icons.filter_list),
                  ),
              ],
            ),
          ),
          Expanded(
            child: workersProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : workersProvider.error != null
                    ? Center(child: Text(workersProvider.error!))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: workersProvider.workers.length,
                        itemBuilder: (context, index) {
                          final w = workersProvider.workers[index];
                          final name = (w['fullName'] ?? 'Worker').toString();
                          final email = (w['email'] ?? '').toString();
                          final status = (w['isActive'] == false) ? 'Inactive' : 'Active';

                          // Determine roles and primary role
                          final rolesRaw = w['roles'] as List<dynamic>?;
                          final roles = rolesRaw != null && rolesRaw.isNotEmpty
                              ? rolesRaw.cast<String>()
                              : [(w['role'] ?? 'staff').toString()];
                          final primaryRole = roles.first;

                          final isMatched = _filterRole == 'All' || roles.contains(_filterRole);
                          if (!isMatched) return const SizedBox.shrink();

                          return WorkerCard(
                            name: name,
                            role: WorkerPermissions.getRoleDisplayName(primaryRole),
                            status: status,
                            email: email,
                            photoUrl: (w['photoUrl'] ?? w['photo_url']) as String?,
                            onTap: () => Navigator.pushNamed(
                              context,
                              Routes.workerDetails,
                              arguments: {
                                'id': w['id'] ?? w['employeeId'] ?? '',
                                'businessId': businessId,
                                'businessType': businessProvider
                                        .currentBusiness?.businessType ??
                                    ''
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

