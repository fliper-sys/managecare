import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../data/local/database_helper.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/customer_repository_impl.dart';
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
  bool _isLoading = true;
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
      // Try local DB first when available (skip or ignore errors on web)
      DatabaseHelper? db;
      try {
        db = DatabaseHelper.instance;
        final local = await db.query('customers', where: 'id = ?', whereArgs: [widget.customerId], limit: 1);
        if (local.isNotEmpty) {
          setState(() {
            _customer = Map<String, dynamic>.from(local.first);
            _isLoading = false;
          });
          return;
        }
      } catch (_) {
        // Local DB may not be available on web or may fail; ignore and fallback to Firestore
        db = null;
      }

      // Fallback to Firestore repository
      final data = await _repository.getCustomerById(widget.customerId);
      if (data == null) {
        setState(() {
          _error = 'Customer not found';
          _isLoading = false;
        });
        return;
      }

      // Persist to local DB for offline availability
      final now = DateTime.now().toIso8601String();
      String createdAtStr;
      try {
        final c = data['createdAt'];
        if (c == null) {
          createdAtStr = now;
        } else if (c is String) {
          createdAtStr = c;
        } else if (c is DateTime) {
          createdAtStr = c.toIso8601String();
        } else if (c is Timestamp) {
          createdAtStr = c.toDate().toIso8601String();
        } else {
          createdAtStr = c.toString();
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
        'totalPurchases': data['totalPurchases'] ?? 0,
        'isActive': (data['isActive'] ?? true) ? 1 : 0,
        'createdAt': createdAtStr,
        'updatedAt': now,
        'syncStatus': 'synced',
      };

      // Persist to local DB when available (ignore errors on web or if DB missing)
      if (db != null) {
        try {
          await db.insert('customers', localRow);
        } catch (e) {
          // ignore DB insert errors
          print('[CustomerDetails] Warning: failed to insert local customer: $e');
        }
      }

      setState(() {
        _customer = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load customer: $e';
        _isLoading = false;
      });
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
              child: const Text('Cancel')),
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Customer deleted')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
    final isActive = customer['isActive'] != false;
    final totalOrders = customer['totalOrders'] ?? 0;
    final totalPurchases = customer['totalPurchases'] ?? 0;
    final createdAt = customer['createdAt'];

    final initials =
        name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();

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
            // Customer Header
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

            // Contact Information
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

            // Purchase Statistics
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
                    value: '₦$totalPurchases',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions
            const _SectionHeader(title: 'Actions'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: CustomButton(
                text: 'Refresh',
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
    if (date == null) return 'Unknown';
    if (date is DateTime) return '${date.day}/${date.month}/${date.year}';
    return date.toString();
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
          Column(
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
                style:
                    AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.heading5.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

