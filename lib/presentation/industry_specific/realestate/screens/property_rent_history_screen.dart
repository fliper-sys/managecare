import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../providers/real_estate_provider.dart';

class PropertyRentHistoryScreen extends StatefulWidget {
  final String propertyId;

  const PropertyRentHistoryScreen({super.key, required this.propertyId});

  @override
  State<PropertyRentHistoryScreen> createState() => _PropertyRentHistoryScreenState();
}

class _PropertyRentHistoryScreenState extends State<PropertyRentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RealEstateProvider>(context, listen: false);
      provider.loadRentPayments();
      provider.loadLeases();
      provider.loadTenants();
      provider.loadProperties();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Property Rent History'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          final property = provider.properties.firstWhere(
            (p) => p.id == widget.propertyId,
            orElse: () => Property.empty(),
          );

          if (property.id.isEmpty) {
            return const Center(
              child: Text('Property not found'),
            );
          }

          // Get all leases for this property
          final propertyLeases = provider.leases
              .where((l) => l.propertyId == widget.propertyId)
              .toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          // Get all rent payments for this property's leases
          final propertyPayments = provider.rentPayments
              .where((p) => propertyLeases.any((l) => l.id == p.leaseId))
              .toList()
            ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

          final totalCollected = propertyPayments
              .where((p) => p.status == 'paid')
              .fold<double>(0, (sum, p) => sum + p.amount);

          final totalPending = propertyPayments
              .where((p) => p.status == 'pending')
              .fold<double>(0, (sum, p) => sum + p.amount);

          final overduePayments = propertyPayments
              .where((p) => p.status == 'overdue')
              .length;

          return Column(
            children: [
              // Property Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                property.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                property.location,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(property.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            property.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(property.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: 'Total Collected',
                          value: '₦${totalCollected.toStringAsFixed(0)}',
                          color: Colors.green,
                        ),
                        _SummaryItem(
                          label: 'Pending',
                          value: '₦${totalPending.toStringAsFixed(0)}',
                          color: Colors.orange,
                        ),
                        _SummaryItem(
                          label: 'Overdue',
                          value: '$overduePayments',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Current Tenant Info (if any)
              if (propertyLeases.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Lease',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final currentLease = propertyLeases.firstWhere(
                            (l) => l.status == 'active',
                            orElse: () => Lease.empty(),
                          );

                          if (currentLease.id.isEmpty) {
                            return const Text('No active lease');
                          }

                          final tenant = provider.tenants.firstWhere(
                            (t) => t.id == currentLease.tenantId,
                            orElse: () => Tenant.empty(),
                          );

                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tenant.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₦${currentLease.monthlyRent.toStringAsFixed(0)}/month',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${DateFormat('MMM yyyy').format(currentLease.startDate)} - ${DateFormat('MMM yyyy').format(currentLease.endDate)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Payment History
              Expanded(
                child: propertyPayments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: AppColors.border),
                            SizedBox(height: 16),
                            Text('No payment history found'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: propertyPayments.length,
                        itemBuilder: (context, index) {
                          final payment = propertyPayments[index];
                          final lease = provider.leases.firstWhere(
                            (l) => l.id == payment.leaseId,
                            orElse: () => Lease.empty(),
                          );
                          final tenant = provider.tenants.firstWhere(
                            (t) => t.id == payment.tenantId,
                            orElse: () => Tenant.empty(),
                          );

                          return _PropertyRentHistoryCard(
                            payment: payment,
                            lease: lease,
                            tenant: tenant,
                            onTap: () => _showPaymentDetails(context, payment, lease, tenant),
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

  void _showPaymentDetails(BuildContext context, RentPayment payment, Lease lease, Tenant tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₦${payment.amount.toStringAsFixed(0)}'),
            Text('Due Date: ${DateFormat('MMM dd, yyyy').format(payment.dueDate)}'),
            if (payment.paidDate != null)
              Text('Paid Date: ${DateFormat('MMM dd, yyyy').format(payment.paidDate!)}'),
            Text('Status: ${payment.status.toUpperCase()}'),
            Text('Payment Method: ${payment.paymentMethod}'),
            const SizedBox(height: 12),
            const Text('Tenant Information:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Name: ${tenant.name}'),
            Text('Email: ${tenant.email}'),
            Text('Phone: ${tenant.phone}'),
            if (lease.id.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Lease Information:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Monthly Rent: ₦${lease.monthlyRent.toStringAsFixed(0)}'),
              Text('Lease Period: ${DateFormat('MMM dd, yyyy').format(lease.startDate)} - ${DateFormat('MMM dd, yyyy').format(lease.endDate)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'rented':
        return Colors.blue;
      case 'sold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _PropertyRentHistoryCard extends StatelessWidget {
  final RentPayment payment;
  final Lease lease;
  final Tenant tenant;
  final VoidCallback onTap;

  const _PropertyRentHistoryCard({
    required this.payment,
    required this.lease,
    required this.tenant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = payment.status == 'overdue' &&
        payment.dueDate.isBefore(DateTime.now());
    // final isPaid = payment.status == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(payment.status),
          child: Icon(
            _getStatusIcon(payment.status),
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '₦${payment.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              tenant.name,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Due: ${DateFormat('MMM dd, yyyy').format(payment.dueDate)}',
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.grey[600],
              ),
            ),
            if (payment.paidDate != null)
              Text(
                'Paid: ${DateFormat('MMM dd, yyyy').format(payment.paidDate!)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            if (lease.id.isNotEmpty)
              Text(
                'Lease: ${DateFormat('MMM yyyy').format(lease.startDate)} - ${DateFormat('MMM yyyy').format(lease.endDate)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(payment.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            payment.status.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(payment.status),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'overdue':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }
}