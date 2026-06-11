import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/auto_provider.dart';
import '../../../../providers/business_provider.dart';

class AutoWorkerJobsScreen extends StatefulWidget {
  const AutoWorkerJobsScreen({super.key});

  @override
  State<AutoWorkerJobsScreen> createState() => _AutoWorkerJobsScreenState();
}

class _AutoWorkerJobsScreenState extends State<AutoWorkerJobsScreen> {
  String _filter = 'all';

  Future<void> _refresh(BuildContext context) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
    if (businessId.isNotEmpty) {
      await context.read<AutoProvider>().loadBusinessData(businessId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = context.watch<BusinessProvider>().currentBusiness;
    final auto = context.watch<AutoProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    final assignedJobs = auto.getJobsForWorker(user.id);
    final filteredJobs = _filter == 'all'
        ? assignedJobs
        : assignedJobs.where((job) => job.status == _filter).toList();
    final completedJobs = assignedJobs.where((job) {
      final status = job.status.toLowerCase();
      return status == 'completed' || status == 'invoiced';
    }).length;
    final openJobs = assignedJobs.length - completedJobs;
    final completionRate = auto.getWorkerCompletionRate(user.id);
    final earnings = auto.getWorkerEarnings(user.id);
    final approvedEarnings = auto.getWorkerApprovedEarnings(user.id);
    final pendingEarnings = auto.getWorkerPendingEarnings(user.id);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blueGrey.shade900,
              Colors.blueGrey.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: _HeaderCard(
                      name: user.fullName,
                      role: user.role,
                      businessName: business?.name ?? 'Workshop',
                      completionRate: completionRate,
                      earnings: earnings,
                      approvedEarnings: approvedEarnings,
                      pendingEarnings: pendingEarnings,
                      assignedJobs: assignedJobs.length,
                      openJobs: openJobs,
                      onLogout: () async {
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed(Routes.login);
                        }
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            label: 'Assigned',
                            value: assignedJobs.length.toString(),
                            icon: Icons.assignment_outlined,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Complete',
                            value: completedJobs.toString(),
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Approved',
                            value: formatCurrency(approvedEarnings),
                            icon: Icons.payments_outlined,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Jobs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All',
                                selected: _filter == 'all',
                                onTap: () => setState(() => _filter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Pending',
                                selected: _filter == 'pending',
                                onTap: () => setState(() => _filter = 'pending'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'In Progress',
                                selected: _filter == 'in-progress',
                                onTap: () => setState(() => _filter = 'in-progress'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Completed',
                                selected: _filter == 'completed',
                                onTap: () => setState(() => _filter = 'completed'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: auto.isLoadingData
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : filteredJobs.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(
                                title: assignedJobs.isEmpty
                                    ? 'No jobs assigned yet'
                                    : 'No jobs match this filter',
                                subtitle: assignedJobs.isEmpty
                                    ? 'As soon as the receptionist assigns a job to you, it will appear here in real time.'
                                    : 'Try another filter or pull to refresh.',
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final job = filteredJobs[index];
                                  final vehicle = auto.getVehicleById(job.vehicleId);
                                  final status = job.status.toLowerCase();
                                  final canComplete = status != 'completed' && status != 'invoiced';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _JobCard(
                                      job: job,
                                      vehicleName: vehicle == null
                                          ? 'Vehicle not found'
                                          : '${vehicle.year} ${vehicle.make} ${vehicle.model}',
                                      plate: vehicle?.licensePlate ?? '',
                                      customerLabel: job.customerId?.isNotEmpty == true
                                          ? 'Customer ID: ${job.customerId}'
                                          : 'No customer attached',
                                      onComplete: canComplete
                                          ? () async {
                                              final ok = await auto.updateJobStatus(job.id, 'completed');
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    ok
                                                        ? 'Job marked complete'
                                                        : 'Unable to update job',
                                                  ),
                                                ),
                                              );
                                            }
                                          : null,
                                      onViewDetails: () => _showDetails(context, job),
                                    ),
                                  );
                                },
                                childCount: filteredJobs.length,
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, Job job) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job ${job.id}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _DetailLine('Status', job.status),
              _DetailLine('Commission', job.commissionStatus),
              _DetailLine('Description', job.description?.isNotEmpty == true ? job.description! : 'No description provided'),
              _DetailLine('Workmanship', formatCurrency(job.workmanshipAmount)),
              _DetailLine('Rate', '${job.workmanshipRate.toStringAsFixed(1)}%'),
              const SizedBox(height: 12),
              if (job.tasks.isNotEmpty) ...[
                const Text('Services', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...job.tasks.map(
                  (task) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.handyman_outlined),
                    title: Text(task.name),
                    subtitle: Text(formatCurrency(task.laborCost)),
                  ),
                ),
              ],
              if (job.usedParts.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Parts', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...job.usedParts.map(
                  (part) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(part.name),
                    subtitle: Text('Qty ${part.quantity} • ${formatCurrency(part.cost)}'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String role;
  final String businessName;
  final double completionRate;
  final double earnings;
  final double approvedEarnings;
  final double pendingEarnings;
  final int assignedJobs;
  final int openJobs;
  final VoidCallback onLogout;

  const _HeaderCard({
    required this.name,
    required this.role,
    required this.businessName,
    required this.completionRate,
    required this.earnings,
    required this.approvedEarnings,
    required this.pendingEarnings,
    required this.assignedJobs,
    required this.openJobs,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade700,
            Colors.blueGrey.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.engineering_outlined, color: Colors.white, size: 30),
              ),
              const Spacer(),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$role • $businessName',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(label: 'Assigned $assignedJobs'),
              _Pill(label: 'Open $openJobs'),
              _Pill(label: '${completionRate.toStringAsFixed(0)}% Done'),
              _Pill(label: 'Approved ${formatCurrency(approvedEarnings)}'),
              _Pill(label: 'Pending ${formatCurrency(pendingEarnings)}'),
              _Pill(label: 'Total ${formatCurrency(earnings)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.indigo.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.indigo.shade900 : Colors.grey.shade800,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final String vehicleName;
  final String plate;
  final String customerLabel;
  final VoidCallback? onComplete;
  final VoidCallback onViewDetails;

  const _JobCard({
    required this.job,
    required this.vehicleName,
    required this.plate,
    required this.customerLabel,
    required this.onComplete,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final status = job.status.toLowerCase();
    final Color statusColor = switch (status) {
      'completed' => Colors.green,
      'invoiced' => Colors.purple,
      'in-progress' => Colors.blue,
      _ => Colors.orange,
    };

    return InkWell(
      onTap: onViewDetails,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.car_repair_rounded, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plate.isEmpty ? customerLabel : '$plate • $customerLabel',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              job.description?.isNotEmpty == true
                  ? job.description!
                  : 'No job description provided.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniBadge(
                  icon: Icons.payments_outlined,
                  label: formatCurrency(job.totalCost),
                ),
                const SizedBox(width: 10),
                _MiniBadge(
                  icon: Icons.percent,
                  label: '${job.workmanshipRate.toStringAsFixed(1)}%',
                ),
                const SizedBox(width: 10),
                _MiniBadge(
                  icon: Icons.savings_outlined,
                  label: formatCurrency(job.workmanshipAmount),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(status == 'completed' ? 'Completed' : 'Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'completed'
                          ? Colors.green.shade200
                          : Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.green.shade200,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.blueGrey.shade700),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.garage_outlined, size: 42, color: Colors.blueGrey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
