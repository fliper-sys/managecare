import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/auto_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../services/thermal_printing_service.dart';
import 'job_card_screen.dart';

class RepairJobsScreen extends StatefulWidget {
  const RepairJobsScreen({super.key});

  @override
  State<RepairJobsScreen> createState() => _RepairJobsScreenState();
}

class _RepairJobsScreenState extends State<RepairJobsScreen> {
  String _filterStatus = 'all';
  String _filterCommission = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final business = context.watch<BusinessProvider>().currentBusiness;

    return Consumer<AutoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (provider.dataError != null) {
          return Scaffold(body: Center(child: Text(provider.dataError!)));
        }

        final filteredJobs = provider.jobs.where((job) {
          final statusMatch =
              _filterStatus == 'all' || job.status == _filterStatus;
          final commissionMatch = _filterCommission == 'all' ||
              job.commissionStatus == _filterCommission;
          final query = _query.trim().toLowerCase();
          final vehicle = provider.getVehicleById(job.vehicleId);
          final haystack = [
            job.id,
            job.description ?? '',
            job.assignedWorkerName ?? '',
            job.assignedWorkerId ?? '',
            job.customerId ?? '',
            vehicle?.make ?? '',
            vehicle?.model ?? '',
            vehicle?.licensePlate ?? '',
            vehicle?.vin ?? '',
          ].join(' ').toLowerCase();
          final queryMatch = query.isEmpty || haystack.contains(query);
          return statusMatch && commissionMatch && queryMatch;
        }).toList();

        final totalJobs = provider.jobs.length;
        final completedJobs = provider.jobs
            .where((job) => job.status == 'completed' || job.status == 'invoiced')
            .length;
        final pendingJobs = provider.jobs.where((job) => job.status == 'pending').length;
        final approvedJobs =
            provider.jobs.where((job) => job.commissionStatus == 'approved').length;
        final totalRevenue = provider.getTotalJobsRevenue();
        final approvedCommissionTotal = provider.jobs
            .where((job) =>
                job.commissionStatus == 'approved' || job.commissionStatus == 'paid')
            .fold<double>(0.0, (sum, job) => sum + job.workmanshipAmount);
        final pendingCommissionTotal = provider.jobs
            .where((job) => job.commissionStatus == 'pending')
            .fold<double>(0.0, (sum, job) => sum + job.workmanshipAmount);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Job History'),
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () async {
                  final businessId = business?.id ?? '';
                  if (businessId.isNotEmpty) {
                    await provider.loadBusinessData(businessId);
                  }
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              final businessId = business?.id ?? '';
              if (businessId.isNotEmpty) {
                await provider.loadBusinessData(businessId);
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                  _SummaryHeader(
                    totalJobs: totalJobs,
                    completedJobs: completedJobs,
                    pendingJobs: pendingJobs,
                    approvedJobs: approvedJobs,
                    totalRevenue: totalRevenue,
                    approvedCommissionTotal: approvedCommissionTotal,
                    pendingCommissionTotal: pendingCommissionTotal,
                  ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search jobs, plates, customers, workers',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 12),
                _buildFilterRow(),
                const SizedBox(height: 12),
                if (filteredJobs.isEmpty)
                  _EmptyHistory(
                    title: 'No jobs found',
                    subtitle: 'Try a different search or filter.',
                  )
                else
                  ...filteredJobs.map(
                    (job) {
                      final vehicle = provider.getVehicleById(job.vehicleId);
                      final canApprove = _canApproveCommission(auth, job);
                      final canPrint = true;
                      final customerText = job.customerId?.isNotEmpty == true
                          ? 'Customer ID: ${job.customerId}'
                          : 'No customer attached';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _JobTile(
                          job: job,
                          vehicleName: vehicle == null
                              ? 'Vehicle not found'
                              : '${vehicle.year} ${vehicle.make} ${vehicle.model}',
                          plate: vehicle?.licensePlate ?? '',
                          customerText: customerText,
                          commissionBadge: _commissionLabel(job),
                          onViewDetails: () => _showDetails(context, provider, job),
                          onPrintReceipt: canPrint
                              ? () => _printReceipt(
                                    context,
                                    business?.name ?? 'Workshop',
                                    provider,
                                    job,
                                    vehicleName: vehicle == null
                                        ? 'Unknown vehicle'
                                        : '${vehicle.year} ${vehicle.make} ${vehicle.model}',
                                    plate: vehicle?.licensePlate ?? '',
                                  )
                              : null,
                          onApproveCommission: canApprove
                              ? () async {
                                  final ok = await provider.approveCommission(
                                    job.id,
                                    approvedBy: auth.currentUser?.fullName,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Commission approved'
                                            : 'Unable to approve commission',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ChoicePill(
            label: 'All Jobs',
            selected: _filterStatus == 'all' && _filterCommission == 'all',
            onTap: () => setState(() {
              _filterStatus = 'all';
              _filterCommission = 'all';
            }),
          ),
          const SizedBox(width: 8),
          _ChoicePill(
            label: 'Pending',
            selected: _filterStatus == 'pending',
            onTap: () => setState(() => _filterStatus = 'pending'),
          ),
          const SizedBox(width: 8),
          _ChoicePill(
            label: 'In Progress',
            selected: _filterStatus == 'in-progress',
            onTap: () => setState(() => _filterStatus = 'in-progress'),
          ),
          const SizedBox(width: 8),
          _ChoicePill(
            label: 'Completed',
            selected: _filterStatus == 'completed',
            onTap: () => setState(() => _filterStatus = 'completed'),
          ),
          const SizedBox(width: 8),
          _ChoicePill(
            label: 'Commission Pending',
            selected: _filterCommission == 'pending',
            onTap: () => setState(() => _filterCommission = 'pending'),
          ),
          const SizedBox(width: 8),
          _ChoicePill(
            label: 'Approved',
            selected: _filterCommission == 'approved',
            onTap: () => setState(() => _filterCommission = 'approved'),
          ),
          const SizedBox(width: 8),
          _ChoicePill(
            label: 'Paid',
            selected: _filterCommission == 'paid',
            onTap: () => setState(() => _filterCommission = 'paid'),
          ),
        ],
      ),
    );
  }

  String _commissionLabel(Job job) {
    final status = job.commissionStatus;
    switch (status) {
      case 'approved':
        return 'Commission approved';
      case 'paid':
        return 'Commission paid';
      default:
        return 'Commission pending';
    }
  }

  bool _canApproveCommission(AuthProvider auth, Job job) {
    final user = auth.currentUser;
    final isAdmin = auth.isAdminUser || auth.isOwnerUser;
    final completed = job.status == 'completed' || job.status == 'invoiced';
    final pendingApproval = job.commissionStatus == 'pending';
    return user != null && isAdmin && completed && pendingApproval;
  }

  Future<void> _printReceipt(
    BuildContext context,
    String businessName,
    AutoProvider provider,
    Job job, {
    required String vehicleName,
    required String plate,
  }) async {
    final receipt = _buildReceiptText(
      businessName: businessName,
      provider: provider,
      job: job,
      vehicleName: vehicleName,
      plate: plate,
    );

    final ok = await ThermalPrintingService().printTextReceipt(
      receiptText: receipt,
      businessName: businessName,
      paperWidth: 80,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Receipt sent to printer' : 'Printing failed')),
    );
  }

  String _buildReceiptText({
    required String businessName,
    required AutoProvider provider,
    required Job job,
    required String vehicleName,
    required String plate,
  }) {
    final buffer = StringBuffer();
    final customer = job.customerId?.isNotEmpty == true ? job.customerId : 'Walk-in';
    final worker = job.assignedWorkerName ?? job.assignedWorkerId ?? 'Unassigned';
    final vehicle = provider.getVehicleById(job.vehicleId);
    final subtotal = job.workmanshipAmount > 0
        ? (job.totalCost - job.workmanshipAmount)
        : job.totalCost;

    buffer.writeln(businessName);
    buffer.writeln('JOB RECEIPT');
    buffer.writeln('Job: ${job.id}');
    buffer.writeln('Date: ${job.createdAt.toLocal()}');
    buffer.writeln('Customer: $customer');
    buffer.writeln('Worker: $worker');
    buffer.writeln('Vehicle: $vehicleName');
    if (plate.isNotEmpty) buffer.writeln('Plate: $plate');
    if ((job.description ?? '').isNotEmpty) {
      buffer.writeln('Work: ${job.description}');
    }
    buffer.writeln('');
    buffer.writeln('Services:');
    for (final task in job.tasks) {
      buffer.writeln('- ${task.name} @ ${formatCurrency(task.laborCost)}');
    }
    buffer.writeln('Parts:');
    for (final part in job.usedParts) {
      buffer.writeln('- ${part.name} x${part.quantity} @ ${formatCurrency(part.cost)}');
    }
    buffer.writeln('');
    buffer.writeln('Subtotal: ${formatCurrency(subtotal)}');
    buffer.writeln('Workmanship: ${formatCurrency(job.workmanshipAmount)}');
    buffer.writeln('Total: ${formatCurrency(job.totalCost)}');
    buffer.writeln('Commission: ${job.commissionStatus}');
    return buffer.toString();
  }

  void _showDetails(BuildContext context, AutoProvider provider, Job job) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final vehicle = provider.getVehicleById(job.vehicleId);
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
              _DetailLine('Vehicle', vehicle == null
                  ? job.vehicleId
                  : '${vehicle.year} ${vehicle.make} ${vehicle.model}'),
              _DetailLine('Description',
                  job.description?.isNotEmpty == true ? job.description! : 'No description provided'),
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
                    subtitle:
                        Text('Qty ${part.quantity} • ${formatCurrency(part.cost)}'),
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

class _SummaryHeader extends StatelessWidget {
  final int totalJobs;
  final int completedJobs;
  final int pendingJobs;
  final int approvedJobs;
  final double totalRevenue;
  final double approvedCommissionTotal;
  final double pendingCommissionTotal;

  const _SummaryHeader({
    required this.totalJobs,
    required this.completedJobs,
    required this.pendingJobs,
    required this.approvedJobs,
    required this.totalRevenue,
    required this.approvedCommissionTotal,
    required this.pendingCommissionTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.blueGrey.shade900],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workshop History',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Track every repair order, approval, and receipt in one place.',
            style: TextStyle(color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Pill(label: 'Jobs $totalJobs'),
              _Pill(label: 'Done $completedJobs'),
              _Pill(label: 'Pending $pendingJobs'),
              _Pill(label: 'Approved $approvedJobs'),
              _Pill(label: 'Revenue ${formatCurrency(totalRevenue)}'),
              _Pill(label: 'Paid ${formatCurrency(approvedCommissionTotal)}'),
              _Pill(label: 'Pending ${formatCurrency(pendingCommissionTotal)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
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

class _JobTile extends StatelessWidget {
  final Job job;
  final String vehicleName;
  final String plate;
  final String customerText;
  final String commissionBadge;
  final VoidCallback onViewDetails;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onApproveCommission;

  const _JobTile({
    required this.job,
    required this.vehicleName,
    required this.plate,
    required this.customerText,
    required this.commissionBadge,
    required this.onViewDetails,
    required this.onPrintReceipt,
    required this.onApproveCommission,
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

    return Container(
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plate.isEmpty ? customerText : '$plate • $customerText',
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                icon: Icons.payments_outlined,
                label: formatCurrency(job.totalCost),
              ),
              _MiniBadge(
                icon: Icons.percent,
                label: '${job.workmanshipRate.toStringAsFixed(1)}%',
              ),
              _MiniBadge(
                icon: Icons.savings_outlined,
                label: formatCurrency(job.workmanshipAmount),
              ),
              _MiniBadge(
                icon: Icons.verified_outlined,
                label: commissionBadge,
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
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrintReceipt,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ),
              if (onApproveCommission != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApproveCommission,
                    icon: const Icon(Icons.approval_outlined),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
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

class _EmptyHistory extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyHistory({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_outlined, size: 42, color: Colors.blueGrey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
