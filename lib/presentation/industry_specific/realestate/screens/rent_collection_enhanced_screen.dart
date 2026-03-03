import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../core/utils/context_extensions.dart';
import '../providers/real_estate_provider.dart';

class RentCollectionScreenEnhanced extends StatefulWidget {
  const RentCollectionScreenEnhanced({super.key});

  @override
  State<RentCollectionScreenEnhanced> createState() =>
      _RentCollectionScreenEnhancedState();
}

class _RentCollectionScreenEnhancedState
    extends State<RentCollectionScreenEnhanced> {
  String _filterStatus = 'all'; // all, pending, paid, overdue

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.tryRead<RealEstateProvider>();
      if (provider != null) {
        provider.loadRentPayments();
        provider.loadLeases();
        provider.loadTenants();
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          final p2 = context.tryRead<RealEstateProvider>();
          p2?.loadRentPayments();
          p2?.loadLeases();
          p2?.loadTenants();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rent Collection'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<RealEstateProvider>(
        builder: (context, provider, _) {
          var payments = provider.rentPayments;

          // Apply filters
          if (_filterStatus != 'all') {
            payments =
                payments.where((p) => p.status == _filterStatus).toList();
          }

          return Column(
            children: [
              // Summary Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _SummaryCard(
                      title: 'Total Pending',
                      amount:
                          '₦${provider.getPendingRent().toStringAsFixed(0)}',
                      color: Colors.orange,
                      count: provider.rentPayments
                          .where((p) => p.status == 'pending')
                          .length,
                    ),
                    const SizedBox(width: 12),
                    _SummaryCard(
                      title: 'Overdue',
                      amount:
                          '₦${provider.getOverduePayments().fold<double>(0, (sum, p) => sum + p.amount)}',
                      color: Colors.red,
                      count: provider.getOverduePayments().length,
                    ),
                    const SizedBox(width: 12),
                    _SummaryCard(
                      title: 'Collected Today',
                      amount: _calculateTodayCollection(provider),
                      color: Colors.green,
                      count: provider.rentPayments
                          .where(
                              (p) => p.status == 'paid' && _isToday(p.paidDate))
                          .length,
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
                      label: 'All (${payments.length})',
                      isSelected: _filterStatus == 'all',
                      onTap: () => setState(() => _filterStatus = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      isSelected: _filterStatus == 'pending',
                      onTap: () => setState(() => _filterStatus = 'pending'),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Overdue',
                      isSelected: _filterStatus == 'overdue',
                      onTap: () => setState(() => _filterStatus = 'overdue'),
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Paid',
                      isSelected: _filterStatus == 'paid',
                      onTap: () => setState(() => _filterStatus = 'paid'),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Payment List
              Expanded(
                child: payments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payments_outlined,
                                size: 64, color: AppColors.border),
                            SizedBox(height: 16),
                            Text('No payments found',
                                style: AppTextStyles.body1),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          final lease = provider.leases.firstWhere(
                              (l) => l.id == payment.leaseId,
                              orElse: () => Lease.empty());
                          final tenant = provider.tenants.firstWhere(
                              (t) => t.id == payment.tenantId,
                              orElse: () => Tenant.empty());

                          return _PaymentCard(
                            payment: payment,
                            lease: lease,
                            tenant: tenant,
                            onMarkPaid: () =>
                                _showMarkPaidDialog(context, payment, provider),
                            onViewDetails: () => _showPaymentDetailsDialog(
                                context, payment, lease, tenant),
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

  String _calculateTodayCollection(RealEstateProvider provider) {
    final today = DateTime.now();
    final todayPayments = provider.rentPayments.where((p) {
      final paidDate = p.paidDate;
      return p.status == 'paid' &&
          paidDate != null &&
          _isSameDay(paidDate, today);
    });
    final total = todayPayments.fold<double>(0, (sum, p) => sum + p.amount);
    return '₦${total.toStringAsFixed(0)}';
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showMarkPaidDialog(
      BuildContext context, RentPayment payment, RealEstateProvider provider) {
    final amountController =
        TextEditingController(text: payment.amount.toString());
    String selectedMethod = payment.paymentMethod;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Mark Payment as Paid'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: '₦',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'check', child: Text('Check')),
                    DropdownMenuItem(
                        value: 'online', child: Text('Online Payment')),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedMethod = value ?? 'cash'),
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
              text: 'Confirm Payment',
              onPressed: () async {
                await provider.updateRentPaymentStatus(payment.id, 'paid',
                    paidDate: DateTime.now());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Payment recorded successfully')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetailsDialog(
    BuildContext context,
    RentPayment payment,
    Lease lease,
    Tenant tenant,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Tenant', value: tenant.name),
              const SizedBox(height: 8),
              _DetailRow(
                  label: 'Amount',
                  value: '₦${payment.amount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _DetailRow(
                  label: 'Due Date', value: _formatDate(payment.dueDate)),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Status',
                value: payment.status.toUpperCase(),
                valueColor: _getStatusColor(payment.status),
              ),
              const SizedBox(height: 8),
              _DetailRow(label: 'Payment Method', value: payment.paymentMethod),
              if (payment.paidDate != null) ...[
                const SizedBox(height: 8),
                _DetailRow(
                    label: 'Paid Date', value: _formatDate(payment.paidDate!)),
              ],
              const SizedBox(height: 8),
              _DetailRow(
                  label: 'Monthly Rent',
                  value: '₦${lease.monthlyRent.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _DetailRow(label: 'Property', value: lease.propertyId),
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
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final int count;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(amount, style: AppTextStyles.heading3.copyWith(color: color)),
          const SizedBox(height: 4),
          Text('$count items',
              style: AppTextStyles.body2
                  .copyWith(color: AppColors.textSecondary, fontSize: 10)),
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
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: (color ?? AppColors.primary).withOpacity(0.1),
      side: BorderSide(
        color: isSelected ? (color ?? AppColors.primary) : AppColors.border,
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final RentPayment payment;
  final Lease lease;
  final Tenant tenant;
  final VoidCallback onMarkPaid;
  final VoidCallback onViewDetails;

  const _PaymentCard({
    required this.payment,
    required this.lease,
    required this.tenant,
    required this.onMarkPaid,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final daysOverdue = _calculateDaysOverdue();
    final isOverdue = DateTime.now().isAfter(payment.dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue && payment.status == 'pending'
              ? Colors.red
              : AppColors.border,
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
                    Text(tenant.name,
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text('Lease: ${lease.propertyId}',
                        style: AppTextStyles.body2
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(payment.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  payment.status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(payment.status),
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
                  Text('Amount',
                      style: AppTextStyles.body2
                          .copyWith(color: AppColors.textSecondary)),
                  Text('₦${payment.amount.toStringAsFixed(2)}',
                      style: AppTextStyles.heading3),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Due Date',
                      style: AppTextStyles.body2
                          .copyWith(color: AppColors.textSecondary)),
                  Text(_formatDate(payment.dueDate),
                      style: AppTextStyles.body1),
                  if (isOverdue && payment.status == 'pending') ...[
                    const SizedBox(height: 4),
                    Text('$daysOverdue days overdue',
                        style: AppTextStyles.body2
                            .copyWith(color: Colors.red, fontSize: 10)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (payment.status == 'pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text('Details'),
                ),
                const SizedBox(width: 8),
                CustomButton(
                  text: 'Mark Paid',
                  onPressed: onMarkPaid,
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text('Details'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

  int _calculateDaysOverdue() {
    final now = DateTime.now();
    if (now.isBefore(payment.dueDate)) return 0;
    return now.difference(payment.dueDate).inDays;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
        Text(value,
            style: AppTextStyles.body1
                .copyWith(color: valueColor, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

