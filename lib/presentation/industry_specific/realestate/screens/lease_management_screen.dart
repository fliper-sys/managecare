import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../core/utils/context_extensions.dart';
import '../providers/real_estate_provider.dart';

class LeaseManagementScreenEnhanced extends StatefulWidget {
  const LeaseManagementScreenEnhanced({super.key});

  @override
  State<LeaseManagementScreenEnhanced> createState() =>
      _LeaseManagementScreenEnhancedState();
}

class _LeaseManagementScreenEnhancedState
    extends State<LeaseManagementScreenEnhanced> {
  String _filterStatus = 'all'; // all, active, expired, upcoming

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.tryRead<RealEstateProvider>();
      if (provider != null) {
        provider.loadLeases();
        provider.loadProperties();
        provider.loadTenants();
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          final p2 = context.tryRead<RealEstateProvider>();
          p2?.loadLeases();
          p2?.loadProperties();
          p2?.loadTenants();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Lease Management'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateLeaseDialog(context),
          ),
        ],
      ),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          var leases = provider.leases;

          // Apply filters
          if (_filterStatus != 'all') {
            leases = leases.where((l) => l.status == _filterStatus).toList();
          }

          return Column(
            children: [
              // Statistics
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatCard(
                      title: 'Active Leases',
                      count: provider.leases
                          .where((l) => l.status == 'active')
                          .length,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      title: 'Expired',
                      count: provider.leases
                          .where((l) => l.status == 'expired')
                          .length,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      title: 'Total Deposit',
                      count: provider.leases
                          .fold(0, (sum, l) => sum + l.deposit.toInt()),
                      color: AppColors.primary,
                      isAmount: true,
                    ),
                  ],
                ),
              ),
              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All (${leases.length})',
                      isSelected: _filterStatus == 'all',
                      onTap: () => setState(() => _filterStatus = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Active',
                      isSelected: _filterStatus == 'active',
                      onTap: () => setState(() => _filterStatus = 'active'),
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Expired',
                      isSelected: _filterStatus == 'expired',
                      onTap: () => setState(() => _filterStatus = 'expired'),
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Lease List
              Expanded(
                child: leases.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.description_outlined,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text(
                              'No leases found',
                              style: AppTextStyles.body1.copyWith(color: scheme.onSurface),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: leases.length,
                        itemBuilder: (context, index) {
                          final lease = leases[index];
                          final property = provider.properties.firstWhere(
                              (p) => p.id == lease.propertyId,
                              orElse: () => Property.empty());
                          final tenant = provider.tenants.firstWhere(
                              (t) => t.id == lease.tenantId,
                              orElse: () => Tenant.empty());

                          return _LeaseCard(
                            lease: lease,
                            property: property,
                            tenant: tenant,
                            onViewDetails: () => _showLeaseDetailsDialog(
                                context, lease, property, tenant),
                            onRenew: () =>
                                _showRenewLeaseDialog(context, lease, provider),
                            onTerminate: () =>
                                _showTerminateDialog(context, lease, provider),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateLeaseDialog(BuildContext context) {
    final provider = context.tryRead<RealEstateProvider>();
    if (provider == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service not available. Try again.')));
      return;
    }

    String selectedPropertyId = '';
    String selectedTenantId = '';
    String selectedLeaseType = 'monthly_rent';
    DateTime selectedStartDate = DateTime.now();
    DateTime selectedEndDate = DateTime.now().add(const Duration(days: 365));
    final monthlyRentController = TextEditingController();
    final depositController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Lease'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      selectedPropertyId.isEmpty ? null : selectedPropertyId,
                  decoration: InputDecoration(
                    labelText: 'Select Property',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: provider.getAvailableProperties().map((prop) {
                    return DropdownMenuItem(
                      value: prop.id,
                      child: Text(prop.title),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedPropertyId = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      selectedTenantId.isEmpty ? null : selectedTenantId,
                  decoration: InputDecoration(
                    labelText: 'Select Tenant',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: provider.tenants.map((tenant) {
                    return DropdownMenuItem(
                      value: tenant.id,
                      child: Text(tenant.name),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedTenantId = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedLeaseType,
                  decoration: InputDecoration(
                    labelText: 'Lease Type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'short_let', child: Text('Short Let')),
                    DropdownMenuItem(value: 'monthly_rent', child: Text('Monthly Rent')),
                    DropdownMenuItem(value: 'yearly_rent', child: Text('Yearly Rent')),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedLeaseType = value ?? 'monthly_rent'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthlyRentController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monthly Rent',
                    prefixText: '₦',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: depositController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Deposit Amount',
                    prefixText: '₦',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(_formatDate(selectedStartDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedStartDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                    );
                    if (date != null) {
                      setState(() => selectedStartDate = date);
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(_formatDate(selectedEndDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedEndDate,
                      firstDate: selectedStartDate,
                      lastDate:
                          selectedStartDate.add(const Duration(days: 1825)),
                    );
                    if (date != null) {
                      setState(() => selectedEndDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CustomButton(
              text: 'Create Lease',
              onPressed: () async {
                if (selectedPropertyId.isEmpty ||
                    selectedTenantId.isEmpty ||
                    monthlyRentController.text.isEmpty ||
                    depositController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final lease = Lease(
                  id: DateTime.now().toString(),
                  propertyId: selectedPropertyId,
                  tenantId: selectedTenantId,
                  startDate: selectedStartDate,
                  endDate: selectedEndDate,
                  monthlyRent: double.parse(monthlyRentController.text),
                  deposit: double.parse(depositController.text),
                  leaseType: selectedLeaseType,
                  status: 'active',
                  documentUrl: null,
                  createdAt: DateTime.now(),
                );

                await provider.addLease(lease);

                // Create initial rent payments
                var currentDate = selectedStartDate;
                while (currentDate.isBefore(selectedEndDate)) {
                  final payment = RentPayment(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    leaseId: lease.id,
                    tenantId: selectedTenantId,
                    amount: double.parse(monthlyRentController.text),
                    paymentMethod: '',
                    dueDate: currentDate.add(Duration(
                        days:
                            DateTime(currentDate.year, currentDate.month + 1, 0)
                                .day)),
                    paidDate: null,
                    durationMonths: 1,
                    status: 'pending',
                    createdAt: DateTime.now(),
                  );

                  await provider.recordRentPayment(payment);
                  currentDate = currentDate.add(const Duration(days: 30));
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lease created successfully')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenewLeaseDialog(
      BuildContext context, Lease lease, RealEstateProvider provider) {
    DateTime selectedEndDate = lease.endDate.add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Renew Lease'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Current End Date'),
                subtitle: Text(_formatDate(lease.endDate)),
              ),
              ListTile(
                title: const Text('New End Date'),
                subtitle: Text(_formatDate(selectedEndDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedEndDate,
                    firstDate: lease.endDate,
                    lastDate: lease.endDate.add(const Duration(days: 1825)),
                  );
                  if (date != null) {
                    setState(() => selectedEndDate = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CustomButton(
              text: 'Renew',
              onPressed: () async {
                final updatedLease = Lease(
                  id: lease.id,
                  propertyId: lease.propertyId,
                  tenantId: lease.tenantId,
                  startDate: lease.startDate,
                  endDate: selectedEndDate,
                  monthlyRent: lease.monthlyRent,
                  deposit: lease.deposit,
                  leaseType: lease.leaseType,
                  status: lease.status,
                  documentUrl: lease.documentUrl,
                  createdAt: lease.createdAt,
                );

                await provider.addLease(updatedLease);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lease renewed successfully')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTerminateDialog(
      BuildContext context, Lease lease, RealEstateProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate Lease'),
        content: const Text(
            'Are you sure you want to terminate this lease? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CustomButton(
            text: 'Terminate',
            onPressed: () async {
              await provider.updateLeaseStatus(lease.id, 'terminated');
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lease terminated')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showLeaseDetailsDialog(
      BuildContext context, Lease lease, Property property, Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lease Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Property', value: property.title),
              const SizedBox(height: 8),
              _DetailRow(label: 'Tenant', value: tenant.name),
              const SizedBox(height: 8),
              _DetailRow(
                  label: 'Start Date', value: _formatDate(lease.startDate)),
              const SizedBox(height: 8),
              _DetailRow(label: 'End Date', value: _formatDate(lease.endDate)),
              const SizedBox(height: 8),
              _DetailRow(
                  label: 'Monthly Rent',
                  value: '₦${lease.monthlyRent.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _DetailRow(
                  label: 'Deposit',
                  value: '₦${lease.deposit.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Status',
                value: lease.status.toUpperCase(),
                valueColor:
                    lease.status == 'active' ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                  label: 'Duration',
                  value:
                      '${lease.endDate.difference(lease.startDate).inDays} days'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final bool isAmount;

  const _StatCard({
    required this.title,
    required this.count,
    required this.color,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  AppTextStyles.body2.copyWith(color: scheme.onSurface.withOpacity(0.72))),
          const SizedBox(height: 4),
          Text(
            isAmount ? '₦${count.toString()}' : '$count',
            style: AppTextStyles.heading3.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FilterChip(
      label: Text(label, style: TextStyle(color: scheme.onSurface)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: theme.cardColor,
      selectedColor: (color ?? AppColors.primary).withOpacity(0.1),
      side: BorderSide(
        color: isSelected
            ? (color ?? AppColors.primary)
            : scheme.outline.withOpacity(0.28),
      ),
    );
  }
}

class _LeaseCard extends StatelessWidget {
  final Lease lease;
  final Property property;
  final Tenant tenant;
  final VoidCallback onViewDetails;
  final VoidCallback onRenew;
  final VoidCallback onTerminate;

  const _LeaseCard({
    required this.lease,
    required this.property,
    required this.tenant,
    required this.onViewDetails,
    required this.onRenew,
    required this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    final daysRemaining = lease.endDate.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysRemaining < 30 && daysRemaining > 0;
    final isExpired = daysRemaining <= 0;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpired
              ? Colors.red
              : (isExpiringSoon
                  ? Colors.orange
                  : scheme.outline.withOpacity(0.28)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(property.title,
                        style: AppTextStyles.body1
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            )),
                    Text(tenant.name,
                        style: AppTextStyles.body2
                            .copyWith(color: scheme.onSurface.withOpacity(0.72))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(lease.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lease.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(lease.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Rent',
                      style: AppTextStyles.body2
                          .copyWith(color: scheme.onSurface.withOpacity(0.72))),
                  Text('₦${lease.monthlyRent.toStringAsFixed(2)}',
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      )),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Days Remaining',
                      style: AppTextStyles.body2
                          .copyWith(color: scheme.onSurface.withOpacity(0.72))),
                  Text(
                    '$daysRemaining days',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isExpired
                          ? Colors.red
                          : (isExpiringSoon ? Colors.orange : Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onViewDetails,
                child: const Text('Details'),
              ),
              const SizedBox(width: 8),
              if (lease.status == 'active' && !isExpired)
                TextButton(
                  onPressed: onRenew,
                  child: const Text('Renew'),
                )
              else if (lease.status == 'active' && isExpiringSoon)
                TextButton(
                  onPressed: onRenew,
                  child: const Text('Renew'),
                ),
              if (lease.status == 'active')
                TextButton(
                  onPressed: onTerminate,
                  child: const Text('Terminate',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'active') return Colors.green;
    if (status == 'expired') return Colors.red;
    return Colors.grey;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.body2.copyWith(color: scheme.onSurface.withOpacity(0.72))),
        Text(value,
            style: AppTextStyles.body1
                .copyWith(
                  color: valueColor ?? scheme.onSurface,
                  fontWeight: FontWeight.bold,
                )),
      ],
    );
  }
}
