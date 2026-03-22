import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/real_estate_provider.dart';

class TenantRentHistoryScreen extends StatefulWidget {
  final String tenantId;

  const TenantRentHistoryScreen({super.key, required this.tenantId});

  @override
  State<TenantRentHistoryScreen> createState() => _TenantRentHistoryScreenState();
}

class _TenantRentHistoryScreenState extends State<TenantRentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RealEstateProvider>(context, listen: false);
      provider.loadRentPayments();
      provider.loadLeases();
      provider.loadTenants();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rent History'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          final tenant = provider.tenants.firstWhere(
            (t) => t.id == widget.tenantId,
            orElse: () => Tenant.empty(),
          );

          if (tenant.id.isEmpty) {
            return const Center(
              child: Text('Tenant not found'),
            );
          }

          final tenantPayments = provider.rentPayments
              .where((p) => p.tenantId == widget.tenantId)
              .toList()
            ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

          final totalPaid = tenantPayments
              .where((p) => p.status == 'paid')
              .fold<double>(0, (sum, p) => sum + p.amount);

          final totalPending = tenantPayments
              .where((p) => p.status == 'pending')
              .fold<double>(0, (sum, p) => sum + p.amount);

          final overduePayments = tenantPayments
              .where((p) => p.status == 'overdue')
              .length;

          return Column(
            children: [
              // Tenant Summary Card
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
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                tenant.email,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone),
                          onPressed: () {
                            // TODO: Implement call functionality
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          label: 'Total Paid',
                          value: '₦${totalPaid.toStringAsFixed(0)}',
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

              // Payment History
              Expanded(
                child: tenantPayments.isEmpty
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
                        itemCount: tenantPayments.length,
                        itemBuilder: (context, index) {
                          final payment = tenantPayments[index];
                          final lease = provider.leases.firstWhere(
                            (l) => l.id == payment.leaseId,
                            orElse: () => Lease.empty(),
                          );

                          return _RentHistoryCard(
                            payment: payment,
                            lease: lease,
                            onTap: () => _showPaymentDetails(context, payment, lease),
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

  void _showPaymentDetails(BuildContext context, RentPayment payment, Lease lease) {
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

class _RentHistoryCard extends StatelessWidget {
  final RentPayment payment;
  final Lease lease;
  final VoidCallback onTap;

  const _RentHistoryCard({
    required this.payment,
    required this.lease,
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
        title: Text(
          '₦${payment.amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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