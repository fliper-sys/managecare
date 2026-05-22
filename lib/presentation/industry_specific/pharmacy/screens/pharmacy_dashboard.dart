import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/utils/worker_permissions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/constants/routes.dart';
import '../../../widgets/permissioned_action.dart';

class PharmacyDashboard extends StatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PharmacyProvider>();
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        provider.loadFromRepository(businessId: business.id);
      }
    });
  }

  /// Pull-to-refresh handler for pharmacy dashboard
  Future<void> _refreshPharmacy() async {
    final business = context.read<BusinessProvider>().currentBusiness;
    if (business == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No business selected')));
      return;
    }

    try {
      await context.read<PharmacyProvider>().setBusinessId(business.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pharmacy data refreshed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    }
  }

  Future<void> _handleLogout() async {
    try {
      await context.read<AuthProvider>().logout();
      if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        backgroundColor: AppColors.pharmacy,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Workers',
            onPressed: () => Navigator.pushNamed(context, Routes.workers),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, Routes.pharmacyPos),
        icon: const Icon(Icons.add),
        label: const Text('New Sale'),
        backgroundColor: AppColors.pharmacy,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPharmacy,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Stats (live from PharmacyProvider)
              Consumer<PharmacyProvider>(
                builder: (context, pharmProvider, _) {
                  final drugs = pharmProvider.drugs;
                  final prescriptions = pharmProvider.prescriptions;
                  final expiringCount = drugs
                      .where((d) => d.expiry
                          .isBefore(DateTime.now().add(const Duration(days: 7))))
                      .length;
                  final lowStockCount = drugs.where((d) => d.stock < 5).length;

                  return Column(
                    children: [

                  Container(
                    color: AppColors.pharmacy,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Prescriptions',
                                value: '${prescriptions.length}',
                                subtext: 'Total',
                                icon: Icons.receipt_long,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Drugs',
                                value: '${drugs.length}',
                                subtext: 'In stock',
                                icon: Icons.medical_services,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Expiring',
                                value: '$expiringCount',
                                subtext: 'Next 7 days',
                                icon: Icons.warning_amber,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Low Stock',
                                value: '$lowStockCount',
                                subtext: '< 5 units',
                                icon: Icons.inventory_2,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )]);
                },
              ),

              const SizedBox(height: 20),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Actions', style: AppTextStyles.heading4),
                    const SizedBox(height: 16),
                    // Permission-gated quick actions (build a GridView populated by permissioned widgets)
                    Builder(builder: (context) {
                      final auth = Provider.of<AuthProvider>(context);
                      final role = auth.currentUser?.role ?? '';
                      final widgets = <Widget>[];

                      if (auth.isOwnerUser ||
                          WorkerPermissions.hasPermission(
                              role, 'manage_prescriptions') ||
                          WorkerPermissions.canManageSales(role)) {
                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser ||
                              WorkerPermissions.hasPermission(
                                  role, 'manage_prescriptions') ||
                              WorkerPermissions.canManageSales(role),
                          onTapRoute: Routes.pharmacyAddPrescription,
                          child: _ActionCard(
                            title: 'New Prescription',
                            icon: Icons.note_add_outlined,
                            color: AppColors.pharmacy,
                          ),
                        ));
                      }

                      if (auth.isOwnerUser ||
                          WorkerPermissions.canViewInventory(role)) {
                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser ||
                              WorkerPermissions.canViewInventory(role),
                          onTapRoute: Routes.pharmacyDrugInventory,
                          child: _ActionCard(
                            title: 'Drug Inventory',
                            icon: Icons.medical_services_outlined,
                            color: AppColors.info,
                          ),
                        ));
                      }

                      if (auth.isOwnerUser ||
                          WorkerPermissions.canManageStaff(role) ||
                          WorkerPermissions.hasPermission(
                              role, 'manage_prescriptions')) {
                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser ||
                              WorkerPermissions.canManageStaff(role) ||
                              WorkerPermissions.hasPermission(
                                  role, 'manage_prescriptions'),
                          onTapRoute: Routes.pharmacyPatients,
                          child: _ActionCard(
                            title: 'Patient Records',
                            icon: Icons.people_outline,
                            color: AppColors.accent,
                          ),
                        ));
                      }

                      if (auth.isOwnerUser ||
                          WorkerPermissions.canViewInventory(role)) {
                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser ||
                              WorkerPermissions.canViewInventory(role),
                          onTapRoute: Routes.pharmacyExpiryTracker,
                          child: _ActionCard(
                            title: 'Expiry Tracker',
                            icon: Icons.event_busy_outlined,
                            color: AppColors.error,
                          ),
                        ));
                      }

                      // Add Drug quick action (manage inventory)
                      if (auth.isOwnerUser ||
                          WorkerPermissions.canManageInventory(role)) {
                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser ||
                              WorkerPermissions.canManageInventory(role),
                          onTapRoute: Routes.pharmacyAddDrug,
                          child: _ActionCard(
                            title: 'Add Drug',
                            icon: Icons.add_box_outlined,
                            color: AppColors.pharmacy,
                          ),
                        ));
                      }

                      // POS quick action
                      if (auth.isOwnerUser ||
                          WorkerPermissions.canManageSales(role)) {
                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser || WorkerPermissions.canManageSales(role),
                          onTapRoute: Routes.pharmacyPos,
                          child: _ActionCard(
                            title: 'POS',
                            icon: Icons.point_of_sale_outlined,
                            color: AppColors.success,
                          ),
                        ));
                      }

                      // Sales history / report
                      if (auth.isOwnerUser ||
                          WorkerPermissions.canViewAnalytics(role) ||
                          WorkerPermissions.canViewInventory(role)) {
                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser ||
                              WorkerPermissions.canViewAnalytics(role) ||
                              WorkerPermissions.canViewInventory(role),
                          onTapRoute: Routes.pharmacySalesHistory,
                          child: _ActionCard(
                            title: 'Sales History',
                            icon: Icons.history,
                            color: AppColors.info,
                          ),
                        ));

                        widgets.add(PermissionedAction(
                          allow: (a) =>
                              a.isOwnerUser || WorkerPermissions.canViewAnalytics(role),
                          onTapRoute: Routes.pharmacySalesReport,
                          child: _ActionCard(
                            title: 'Sales Report',
                            icon: Icons.bar_chart,
                            color: AppColors.accent,
                          ),
                        ));

                      // Printer Settings - available to owners and staff/sales managers
                      widgets.add(PermissionedAction(
                        allow: (a) => a.isOwnerUser || WorkerPermissions.canManageStaff(role) || WorkerPermissions.canManageSales(role),
                        onTapRoute: Routes.printerSettings,
                        child: _ActionCard(
                          title: 'Printer Settings',
                          icon: Icons.print,
                          color: Colors.teal,
                        ),
                      ));

                      }

                      if (widgets.isEmpty) {
                        widgets.add(const Center(
                          child: Text('No quick actions available',
                              style: AppTextStyles.caption),
                        ));
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        padding: EdgeInsets.zero,
                        children: widgets,
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Recent Prescriptions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Recent Prescriptions',
                      style: AppTextStyles.heading4),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.pharmacyPrescriptions),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Consumer<PharmacyProvider>(
              builder: (context, pharmProvider, _) {
                final prescriptions = pharmProvider.prescriptions;
                final patients = pharmProvider.patients;

                if (prescriptions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No prescriptions yet'),
                    ),
                  );
                }

                // Show last 5 prescriptions
                final recent = prescriptions.length > 5
                    ? prescriptions.sublist(prescriptions.length - 5)
                    : prescriptions;

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = recent[index];
                    // Safe patient lookup: avoid unsafe orElse that returns null via cast hacks
                    final patient = patients
                            .where((pat) => pat != null && pat.id == p.patientId)
                            .isNotEmpty
                        ? patients.firstWhere((pat) => pat != null && pat.id == p.patientId)
                        : null;
                    final patientName =
                        patient != null ? patient.name : 'Unknown Patient';
                    final drugs = p.items
                        .map((item) => item['drugId'] as String? ?? 'Drug')
                        .join(', ');

                    return _PrescriptionCard(
                      patientName: patientName,
                      prescriptionId: p.id,
                      drugs: drugs.split(',').map((e) => e.trim()).toList(),
                      date: p.createdAt.toString(),
                      status: 'Active',
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // Alerts
            Consumer<PharmacyProvider>(
              builder: (context, pharmProvider, _) {
                final drugs = pharmProvider.drugs;
                final expiringCount = drugs
                    .where((d) => d.expiry
                        .isBefore(DateTime.now().add(const Duration(days: 7))))
                    .length;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiry Alert',
                              style: AppTextStyles.subtitle1.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                            Text(
                              '$expiringCount items expiring within 7 days',
                              style: AppTextStyles.body2,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                            context, Routes.pharmacyExpiryTracker),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Prescription Analytics & Top Prescribed Drugs (merged)
            Consumer<PharmacyProvider>(
              builder: (context, provider, _) {
                final presStats = provider.getPrescriptionStats();
                final topDrugs = provider.getTopPrescribedDrugs(limit: 3);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prescription Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _SmallStatColumn(value: '${presStats['totalPrescriptions']}', label: 'Total', color: Colors.blue),
                                _SmallStatColumn(value: '${presStats['pendingCount']}', label: 'Pending', color: Colors.orange),
                                _SmallStatColumn(value: '${presStats['dispensedCount']}', label: 'Dispensed', color: Colors.green),
                                _SmallStatColumn(value: '₦${(presStats['totalRevenue'] as double).toStringAsFixed(2)}', label: 'Revenue', color: Colors.purple),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Top Prescribed Drugs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            if (topDrugs.isEmpty)
                              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No prescription data yet', style: TextStyle(color: Colors.grey)),))
                            else
                              ...topDrugs.asMap().entries.map((entry) {
                                final index = entry.key;
                                final drug = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              drug['drugName'] as String,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              'Prescribed ${drug['timesIssued']} times',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${drug['totalQuantityDispensed']} units',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(color: color),
          ),
          Text(
            label,
            style: AppTextStyles.body2.copyWith(color: color),
          ),
          Text(
            subtext,
            style: AppTextStyles.caption.copyWith(
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallStatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SmallStatColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
        boxShadow:
            theme.brightness == Brightness.dark ? null : AppColors.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final String patientName;
  final String prescriptionId;
  final List<String> drugs;
  final String date;
  final String status;

  const _PrescriptionCard({
    required this.patientName,
    required this.prescriptionId,
    required this.drugs,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'Pending';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withOpacity(0.24)),
        boxShadow:
            theme.brightness == Brightness.dark ? null : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pharmacy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.pharmacy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patientName, style: AppTextStyles.subtitle1),
                    Text(prescriptionId, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isPending ? AppColors.warning : AppColors.success)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.caption.copyWith(
                    color: isPending ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Drugs: ${drugs.join(", ")}',
            style: AppTextStyles.body2,
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

