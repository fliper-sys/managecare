import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/customer_repository_impl.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/custom_button.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  late CustomerRepositoryImpl _repository;
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _purchaseHistory = [];
  bool _isLoading = true;
  bool _isLoadingHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = CustomerRepositoryImpl(firestore: FirebaseFirestore.instance);
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      DatabaseHelper? db;
      try {
        db = DatabaseHelper.instance;
        final local = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [widget.customerId],
          limit: 1,
        );
        if (local.isNotEmpty) {
          _customer = Map<String, dynamic>.from(local.first);
        }
      } catch (_) {
        db = null;
      }

      final data = await _repository.getCustomerById(widget.customerId);
      if (data == null && _customer == null) {
        setState(() {
          _error = 'Customer not found';
          _isLoading = false;
        });
        return;
      }

      if (data != null) {
        final now = DateTime.now().toIso8601String();
        String createdAtStr;
        try {
          final createdAt = data['createdAt'];
          if (createdAt == null) {
            createdAtStr = now;
          } else if (createdAt is String) {
            createdAtStr = createdAt;
          } else if (createdAt is DateTime) {
            createdAtStr = createdAt.toIso8601String();
          } else if (createdAt is Timestamp) {
            createdAtStr = createdAt.toDate().toIso8601String();
          } else {
            createdAtStr = createdAt.toString();
          }
        } catch (_) {
          createdAtStr = now;
        }

        final localRow = {
          'id': widget.customerId,
          'businessId': data['businessId'] ?? '',
          'name': data['fullName'] ?? data['name'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phoneNumber'] ?? data['phone'] ?? '',
          'address': data['address'] ?? '',
          'city': data['city'] ?? '',
          'state': data['state'] ?? '',
          'loyaltyPoints': data['loyaltyPoints'] ?? 0,
          'totalPurchases': data['totalPurchases'] ?? data['totalSpent'] ?? 0,
          'isActive': (data['isActive'] ?? true) ? 1 : 0,
          'createdAt': createdAtStr,
          'updatedAt': now,
          'syncStatus': 'synced',
        };

        if (db != null) {
          try {
            await db.insert('customers', localRow);
          } catch (e) {
            debugPrint(
              '[CustomerDetails] Warning: failed to insert local customer: $e',
            );
          }
        }

        _customer = Map<String, dynamic>.from(data);
      }

      await _loadPurchaseHistory();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load customer: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPurchaseHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
          _customer?['businessId']?.toString() ??
          '';
      if (businessId.isEmpty) {
        _purchaseHistory = [];
        return;
      }

      final customerProvider = context.read<CustomerProvider>();
      customerProvider.setBusinessId(businessId);
      final history =
          await customerProvider.getCustomerPurchaseHistory(widget.customerId);
      _purchaseHistory = history
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (e) {
      debugPrint('[CustomerDetails] Failed to load purchase history: $e');
      _purchaseHistory = [];
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.deleteCustomer(widget.customerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Customer deleted')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _startSaleForCustomer() async {
    final customer = _customer;
    if (customer == null) return;

    final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
        customer['businessId']?.toString() ??
        '';
    if (businessId.isNotEmpty) {
      context.read<CustomerProvider>().setBusinessId(businessId);
    }

    context.read<CustomerProvider>().selectCustomer(
          CustomerModel.fromJson(customer, documentId: widget.customerId),
        );

    if (!mounted) return;
    Navigator.pushNamed(context, Routes.sales);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Details')),
        body: Center(child: Text(_error!)),
      );
    }

    final customer = _customer ?? {};
    final name = customer['fullName'] ?? customer['name'] ?? 'Unknown';
    final email = customer['email'] ?? 'N/A';
    final phone = customer['phoneNumber'] ?? customer['phone'] ?? 'N/A';
    final address = customer['address'] ?? 'N/A';
    final isActive = customer['isActive'] != false && customer['isActive'] != 0;
    final totalOrders = customer['totalOrders'] ?? customer['totalTransactions'] ?? 0;
    final totalPurchases = _readDouble(
      customer['totalPurchases'] ?? customer['totalSpent'],
    );
    final createdAt = customer['createdAt'];

    final initials = name
        .toString()
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Details'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _deleteCustomer,
                child: const Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'C',
                        style: AppTextStyles.heading4.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.heading5.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Customer since ${_formatDate(createdAt)}',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Active',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Contact Information'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: phone,
                  ),
                  const Divider(),
                  _ContactRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: email,
                  ),
                  const Divider(),
                  _ContactRow(
                    icon: Icons.location_on,
                    label: 'Address',
                    value: address,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Purchase Statistics'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.shopping_bag,
                    label: 'Total Orders',
                    value: '$totalOrders',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.trending_up,
                    label: 'Total Spent',
                    value: 'NGN ${totalPurchases.toStringAsFixed(2)}',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Start New Sale',
                    onPressed: _startSaleForCustomer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadPurchaseHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('Refresh History'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Purchase History'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _isLoadingHistory
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _purchaseHistory.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No purchase history yet for this customer.',
                          ),
                        )
                      : Column(
                          children: _purchaseHistory
                              .map((purchase) => _PurchaseHistoryTile(
                                    purchase: purchase,
                                  ))
                              .toList(),
                        ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Actions'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: CustomButton(
                text: 'Refresh Customer',
                onPressed: _loadCustomer,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    final resolved = _toDateTime(date);
    if (resolved == null) return 'Unknown';
    return DateFormat('dd MMM yyyy').format(resolved);
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.heading5.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.heading5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseHistoryTile extends StatelessWidget {
  final Map<String, dynamic> purchase;

  const _PurchaseHistoryTile({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final createdAt = purchase['createdAt'];
    final total = purchase['totalAmount'] ?? purchase['total'] ?? 0;
    final paymentMethod =
        (purchase['paymentMethod'] ?? 'Unknown').toString();
    final saleId = (purchase['saleId'] ?? purchase['orderId'] ?? 'N/A')
        .toString();
    final items = (purchase['items'] as List?) ?? const [];

    DateTime? resolvedDate;
    if (createdAt is Timestamp) {
      resolvedDate = createdAt.toDate();
    } else if (createdAt is DateTime) {
      resolvedDate = createdAt;
    } else if (createdAt is String) {
      resolvedDate = DateTime.tryParse(createdAt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  saleId,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'NGN ${(total is num ? total.toDouble() : double.tryParse(total.toString()) ?? 0.0).toStringAsFixed(2)}',
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${items.length} item(s) • ${paymentMethod.toUpperCase()}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (resolvedDate != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(resolvedDate),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
