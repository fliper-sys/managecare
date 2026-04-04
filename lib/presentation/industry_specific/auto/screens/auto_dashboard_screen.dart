import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auto_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'job_card_screen.dart';

class AutoDashboardScreen extends StatefulWidget {
  const AutoDashboardScreen({super.key});

  @override
  State<AutoDashboardScreen> createState() => _AutoDashboardScreenState();
}

class _AutoDashboardScreenState extends State<AutoDashboardScreen> {
  bool _initiated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initiated) return;
    _initiated = true;

    final auto = Provider.of<AutoProvider>(context, listen: false);
    try {
      final bp = Provider.of<BusinessProvider>(context, listen: false);
      final currentId = bp.currentBusiness?.id;
      if (currentId != null && currentId.isNotEmpty && auto.currentBusinessId != currentId) {
        auto.setBusinessId(currentId);
      }
    } catch (_) {
      // Ignore in testing environments
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Technical/Clean background
      appBar: AppBar(
        title: const Text('Workshop Overview', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey[900], // Industrial dark header
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                await context.read<AuthProvider>().logout();
                if (context.mounted) Navigator.of(context).pushReplacementNamed(Routes.login);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.white),
            tooltip: 'Manage Workers',
            onPressed: () => Navigator.pushNamed(context, Routes.workers),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AutoProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.dataError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(provider.dataError!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: () async {
                      final id = provider.currentBusinessId;
                      if (id != null && id.isNotEmpty) await provider.loadBusinessData(id);
                    }, child: const Text('Retry'))
                  ],
                ),
              ),
            );
          }

          final activeJobs = provider.getActiveJobCount();
          final openJobs = provider.getOpenJobs();
          
          // Calculate estimated revenue from open jobs for the dashboard
          final estimatedRevenue = openJobs.fold<double>(0, (sum, job) => sum + job.totalCost);

          return RefreshIndicator(
            onRefresh: () async {
              final id = provider.currentBusinessId;
              if (id != null && id.isNotEmpty) {
                await provider.loadBusinessData(id);
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Overview Section
                  const Text('Shop Performance', 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Active Jobs',
                          value: '$activeJobs',
                          icon: Icons.car_repair,
                          color: Colors.blue,
                          onTap: () => Navigator.pushNamed(context, Routes.autoServiceOrders),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Est. Revenue',
                          value: formatCurrency(estimatedRevenue),
                          icon: Icons.attach_money,
                          color: Colors.green,
                          onTap: () => Navigator.pushNamed(context, Routes.autoInvoices),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. Quick Actions
                  const Text('Quick Actions', 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickActionBtn(
                          icon: Icons.add_circle, 
                          label: 'New Job', 
                          color: AppColors.primary,
                          onTap: () => Navigator.pushNamed(context, Routes.autoCreateServiceOrder),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionBtn(
                          icon: Icons.inventory_2, 
                          label: 'Parts', 
                          color: Colors.orange[800]!,
                          onTap: () => Navigator.pushNamed(context, Routes.autoPartsInventory),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionBtn(
                          icon: Icons.history, 
                          label: 'Job History', 
                          color: Colors.blueGrey,
                          onTap: () => Navigator.pushNamed(context, Routes.autoServiceOrders),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionBtn(
                          icon: Icons.person_add, 
                          label: 'Customer', 
                          color: Colors.teal,
                          onTap: () => Navigator.pushNamed(context, Routes.customers),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionBtn(
                          icon: Icons.print, 
                          label: 'Printer Settings', 
                          color: Colors.purple,
                          onTap: () => Navigator.pushNamed(context, Routes.printerSettings),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Work Queue (Job List)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Work Queue', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, Routes.autoServiceOrders),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  
                  if (openJobs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.garage, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('Bay is empty', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: openJobs.take(5).length,
                      itemBuilder: (context, index) {
                        final job = openJobs[index];
                        final vehicle = provider.getVehicleById(job.vehicleId);
                        
                        return _JobTile(
                          jobId: job.id,
                          vehicleName: vehicle?.make ?? "Unknown Vehicle",
                          status: job.status,
                          cost: job.totalCost,
                          onTap: () {
                             Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => JobCardScreen(jobId: job.id)));
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------- Helper Widgets ----------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final String jobId;
  final String vehicleName;
  final String status;
  final double cost;
  final VoidCallback onTap;

  const _JobTile({
    required this.jobId,
    required this.vehicleName,
    required this.status,
    required this.cost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status color
    Color statusColor = Colors.grey;
    if (status.toLowerCase().contains('progress')) statusColor = Colors.blue;
    if (status.toLowerCase().contains('pending')) statusColor = Colors.orange;
    if (status.toLowerCase().contains('done') || status.toLowerCase().contains('complete')) statusColor = Colors.green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // 1. Icon / Image placeholder
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car, color: Colors.blueGrey),
              ),
              const SizedBox(width: 16),
              
              // 2. Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicleName, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Job #$jobId', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 10, color: Colors.grey[300]),
                        const SizedBox(width: 8),
                         Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(status, 
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Price
              Text(formatCurrency(cost), 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

