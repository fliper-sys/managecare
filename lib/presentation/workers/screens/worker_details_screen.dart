import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/worker_repository_impl.dart';
import '../../../providers/retail_provider.dart';
import '../../industry_specific/barber_shop/providers/barber_shop_provider.dart';
import '../../industry_specific/salon/providers/salon_provider.dart';
import '../../../providers/workers_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../core/utils/worker_permissions.dart';

class WorkerDetailsScreen extends StatefulWidget {
  final String workerId;
  final String? businessId;
  final String? businessType;

  const WorkerDetailsScreen({
    super.key,
    required this.workerId,
    this.businessId,
    this.businessType,
  });

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _worker;
  String? _error;

  // Worker sales metrics
  double _workerTotalSales = 0.0;
  int _workerSalesCount = 0;
  bool _loadingSalesMetrics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorker();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorker() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('[WorkerDetails] Loading worker with ID: ${widget.workerId}');
      final repo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
      final data = await repo.getWorkerById(widget.workerId);

      print('[WorkerDetails] Worker data: $data');

      if (data == null) {
        setState(() {
          _error = 'Worker not found with ID: ${widget.workerId}';
          _isLoading = false;
        });
        print(
            '[WorkerDetails] ERROR: Worker document does not exist in Firestore');
        return;
      }

      setState(() {
        _worker = Map<String, dynamic>.from(data as Map<String, dynamic>);
        _isLoading = false;
      });
      print('[WorkerDetails] Worker loaded successfully: ${_worker?['name']}');
      // Load worker sales metrics
      _loadWorkerSalesMetrics();
    } catch (e) {
      setState(() {
        _error = 'Error loading worker: $e';
        _isLoading = false;
      });
      print('[WorkerDetails] Exception: $e');
    }
  }

  Future<void> _loadWorkerSalesMetrics() async {
    try {
      final retailProvider = context.read<RetailProvider>();

      // Get sales for this worker from Firestore
      final workerStoreId = _worker?['storeId'] as String?;
      final totalSales =
          await retailProvider.getWorkerTotalSales(widget.workerId, storeId: workerStoreId);
      final salesCount =
          await retailProvider.getWorkerSalesCount(widget.workerId, storeId: workerStoreId);

      if (mounted) {
        setState(() {
          _workerTotalSales = totalSales;
          _workerSalesCount = salesCount;
          _loadingSalesMetrics = false;
          print(
              '[WorkerDetails] Sales metrics loaded: \u20a6$_workerTotalSales, Count: $_workerSalesCount');
        });
      }
    } catch (e) {
      print('[WorkerDetails] Error loading sales metrics: $e');
      if (mounted) {
        setState(() {
          _loadingSalesMetrics = false;
        });
      }
    }
  }

  Future<void> _showEditCommissionDialog() async {
    final current = _worker?['commissionPercentage'];
    final controller = TextEditingController(text: current?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Commission'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Commission (%)',
              suffixText: '%',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final v = double.tryParse(value);
              if (v == null) return 'Enter a valid number';
              if (v < 0 || v > 100) return 'Enter a percentage between 0 and 100';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              final text = controller.text.trim();
              final parsed = double.tryParse(text) ?? 0.0;

              final repo = WorkerRepositoryImpl(firestore: FirebaseFirestore.instance);
              try {
                await repo.updateWorker(widget.workerId, {
                  'commissionPercentage': parsed,
                  'updatedAt': DateTime.now(),
                });

                // Also update business-scoped barber/stylist docs if available
                final businessId = widget.businessId ?? _worker?['businessId'] as String?;
                final businessType = (widget.businessType ?? _worker?['businessType'] ?? '') as String;
                final roles = (_worker?['roles'] as List<dynamic>?)?.cast<String>() ?? [(_worker?['role'] as String?) ?? ''];
                final businessTypeLow = (businessType).toLowerCase();

                if (businessId != null && businessId.isNotEmpty) {
                  try {
                    // Update collections based on roles. This ensures salon edits work even if businessType varies.
                    if (roles.contains('barber')) {
                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(businessId)
                          .collection('barbers')
                          .doc(widget.workerId)
                          .set({'commissionPercentage': parsed}, SetOptions(merge: true));
                      try { final barberProvider = context.read<BarberShopProvider>(); barberProvider.loadBarbers(); } catch (_) {}
                    }

                    if (roles.contains('hairstylist') || roles.contains('stylist')) {
                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(businessId)
                          .collection('stylists')
                          .doc(widget.workerId)
                          .set({'commissionPercentage': parsed}, SetOptions(merge: true));
                      try { final salonProvider = context.read<SalonProvider>(); salonProvider.loadStylists(); } catch (_) {}
                    }

                    // Fallback: if roles didn't explicitly indicate, use business type hints
                    if (!(roles.contains('barber') || roles.contains('hairstylist') || roles.contains('stylist'))) {
                      if (businessTypeLow.contains('barber')) {
                        await FirebaseFirestore.instance
                            .collection('businesses')
                            .doc(businessId)
                            .collection('barbers')
                            .doc(widget.workerId)
                            .set({'commissionPercentage': parsed}, SetOptions(merge: true));
                        try { final barberProvider = context.read<BarberShopProvider>(); barberProvider.loadBarbers(); } catch (_) {}
                      }
                      if (businessTypeLow.contains('salon')) {
                        await FirebaseFirestore.instance
                            .collection('businesses')
                            .doc(businessId)
                            .collection('stylists')
                            .doc(widget.workerId)
                            .set({'commissionPercentage': parsed}, SetOptions(merge: true));
                        try { final salonProvider = context.read<SalonProvider>(); salonProvider.loadStylists(); } catch (_) {}
                      }
                    }
                  } catch (e) {
                    print('[WorkerDetails] Failed to update business-scoped commission: $e');
                  }
                }

                // Reload worker and show success
                await _loadWorker();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commission updated')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update commission: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditWorkerDialog() async {
    final nameCtrl = TextEditingController(text: _worker?['name'] ?? '');
    final emailCtrl = TextEditingController(text: _worker?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: _worker?['phoneNumber'] ?? _worker?['phone'] ?? '');
    final pinCtrl = TextEditingController(text: _worker?['pin'] ?? '');
    bool isActive = _worker?['isActive'] == true;
    final rolesList = (_worker?['roles'] as List<dynamic>?)?.cast<String>() ?? [(_worker?['role'] as String?) ?? 'staff'];
    final rolesCtrl = TextEditingController(text: rolesList.join(', '));
    final servicesList = (_worker?['serviceNames'] as List<dynamic>?)?.cast<String>() ?? [];
    final servicesCtrl = TextEditingController(text: servicesList.join(', '));
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: const Text('Edit Worker'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final email = v.trim();
                      if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 8),
                  // PIN field (optional)
                  Builder(builder: (ctx) {
                    bool obscurePin = true;
                    return StatefulBuilder(
                      builder: (ctx2, setPinState) => Column(
                        children: [
                          TextFormField(
                            controller: pinCtrl,
                            decoration: InputDecoration(
                              labelText: 'PIN',
                              helperText: 'Optional: 4-6 digit numeric PIN',
                              suffixIcon: IconButton(
                                icon: Icon(obscurePin ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setPinState(() => obscurePin = !obscurePin),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            obscureText: obscurePin,
                            maxLength: 6,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null; // optional
                              final cleaned = v.trim();
                              if (!RegExp(r'^\d{4,6}\$').hasMatch(cleaned)) return 'Enter a 4-6 digit numeric PIN';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  }),
                  Row(
                    children: [
                      const Text('Active'),
                      const SizedBox(width: 8),
                      Switch(
                        value: isActive,
                        onChanged: (v) => setStateSB(() => isActive = v),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: rolesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Roles (comma separated)',
                      helperText: 'e.g. barber, stylist',
                    ),
                  ),
                  TextFormField(
                    controller: servicesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Services (comma separated)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();

                final updateMap = <String, dynamic>{
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phoneNumber': phoneCtrl.text.trim(),
                  'pin': pinCtrl.text.trim(),
                  'isActive': isActive,
                  'roles': rolesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  'serviceNames': servicesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  'updatedAt': DateTime.now(),
                };

                try {
                  final businessId = widget.businessId ?? _worker?['businessId'] as String?;
                  final roles = (updateMap['roles'] as List<dynamic>?)?.cast<String>();
                  await context.read<WorkersProvider>().updateWorker(widget.workerId, updateMap, businessId: businessId, roles: roles);

                  await _loadWorker();
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Worker updated')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed to update worker: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteWorker() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Worker'),
        content: const Text('Are you sure you want to permanently delete this worker? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final businessId = widget.businessId ?? _worker?['businessId'] as String?;
      await context.read<WorkersProvider>().deleteWorker(widget.workerId, businessId: businessId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker deleted')));
        Navigator.of(context).pop(); // go back to list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete worker: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_worker?['name'] ?? 'Worker Details'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          Builder(builder: (ctx) {
            final isOwner = context.watch<AuthProvider>().currentUser?.isOwner ?? false;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit details',
                    onPressed: _showEditWorkerDialog,
                  ),
                IconButton(
                  icon: const Icon(Icons.monetization_on),
                  tooltip: 'Edit commission',
                  onPressed: _showEditCommissionDialog,
                ),
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_forever),
                    tooltip: 'Delete worker',
                    onPressed: _confirmDeleteWorker,
                    color: Colors.redAccent,
                  ),
              ],
            );
          }),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Permissions'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                    ],
                  ),
                )
              : _worker == null
                  ? const Center(child: Text('Worker not found'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildPermissionsTab(),
                        _buildPerformanceTab(),
                      ],
                    ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(
                        photoUrl: (_worker?['photoUrl'] ?? _worker?['photo_url']) as String?,
                        initials: ((_worker?['name'] as String? ?? 'W')[0].toUpperCase()),
                        radius: 32,
                        backgroundColor: AppColors.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _worker?['name'] ?? 'Unknown',
                              style: AppTextStyles.heading3,
                            ),
                            Text(
                              _displayRoles(),
                              style: AppTextStyles.body2Secondary,
                            ),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(
                                _worker?['isActive'] == true
                                    ? 'Active'
                                    : 'Inactive',
                              ),
                              backgroundColor: _worker?['isActive'] == true
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Contact Information', style: AppTextStyles.heading4),
          const SizedBox(height: 8),
          _buildDetailRow('Email', _worker?['email'] ?? 'N/A'),
          _buildDetailRow(
              'Phone', _worker?['phoneNumber'] ?? _worker?['phone'] ?? 'N/A'),
          _buildDetailRow('PIN', _worker?['pin'] != null && _worker!['pin'].toString().isNotEmpty ? '••••' : 'Not set'),
          const SizedBox(height: 16),
          const Text('Employment Information', style: AppTextStyles.heading4),
          const SizedBox(height: 8),
          _buildDetailRow('Role', _displayRoles()),
          _buildDetailRow('Services', _displayServices()),
          _buildDetailRow(
              'Status', _worker?['isActive'] == true ? 'Active' : 'Inactive'),
          _buildDetailRow('Hire Date', _formatHireDate(_worker?['hireDate'])),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    final roles = (_worker?['roles'] as List<dynamic>?)?.cast<String>() ?? [(_worker?['role'] as String? ?? 'staff')];
    final permissionSet = <String>{};
    for (var r in roles) {
      permissionSet.addAll(WorkerPermissions.getPermissionsForRole(r));
    }
    final permissions = permissionSet.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ExpansionTile(
            title: Text(
              roles.map((r) => WorkerPermissions.getRoleDisplayName(r)).join(', '),
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
                                Expanded(
                                  child: Text(permission
                                      .replaceAll('_', ' ')
                                      .toUpperCase()),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Metrics',
                  style: AppTextStyles.heading4,
                ),
                const SizedBox(height: 16),
                _buildMetricRow(
                  'Sales',
                  _loadingSalesMetrics
                      ? 'Loading...'
                      : '₦${_workerTotalSales.toStringAsFixed(2)}',
                ),
                _buildMetricRow(
                  'Transactions',
                  _loadingSalesMetrics
                      ? 'Loading...'
                      : _workerSalesCount.toString(),
                ),
                _buildMetricRow('Attendance Rate', '95%'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatHireDate(dynamic hireDate) {
    if (hireDate == null) return 'N/A';

    try {
      if (hireDate is String) {
        // If it's already a formatted date string, return as is
        return hireDate;
      } else if (hireDate is DateTime) {
        // Format DateTime as readable date
        return '${hireDate.day}/${hireDate.month}/${hireDate.year}';
      }
    } catch (e) {
      print('[WorkerDetails] Error formatting hire date: $e');
    }

    return 'N/A';
  }

  String _displayRoles() {
    try {
      final roles = _worker?['roles'] as List<dynamic>?;
      if (roles != null && roles.isNotEmpty) {
        return roles.map((r) => WorkerPermissions.getRoleDisplayName((r as String?) ?? 'staff')).join(', ');
      }
      // fallback to single role field
      return WorkerPermissions.getRoleDisplayName(_worker?['role'] ?? 'staff');
    } catch (e) {
      return WorkerPermissions.getRoleDisplayName(_worker?['role'] ?? 'staff');
    }
  }

  String _displayServices() {
    try {
      final names = _worker?['serviceNames'] as List<dynamic>?;
      if (names != null && names.isNotEmpty) {
        return names.join(', ');
      }
      final ids = _worker?['serviceIds'] as List<dynamic>?;
      if (ids != null && ids.isNotEmpty) {
        // Return joined ids as fallback
        return ids.join(', ');
      }
    } catch (e) {
      print('[WorkerDetails] Error displaying services: $e');
    }
    return 'N/A';
  }
}

