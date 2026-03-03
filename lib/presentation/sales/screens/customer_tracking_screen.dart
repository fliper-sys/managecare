import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../data/models/customer_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../widgets/custom_app_bar.dart';

class CustomerTrackingScreen extends StatefulWidget {
  const CustomerTrackingScreen({super.key});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  late CustomerProvider customerProvider;
  final searchController = TextEditingController();
  List<CustomerModel> filteredCustomers = [];
  String sortBy = 'recent'; // recent, spending, transactions

  @override
  void initState() {
    super.initState();
    customerProvider = context.read<CustomerProvider>();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    await customerProvider.loadCustomers();
    _applySort();
  }

  void _applySort() {
    setState(() {
      filteredCustomers = List.from(customerProvider.customers);

      switch (sortBy) {
        case 'spending':
          filteredCustomers
              .sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
          break;
        case 'transactions':
          filteredCustomers.sort(
              (a, b) => b.totalTransactions.compareTo(a.totalTransactions));
          break;
        case 'recent':
        default:
          filteredCustomers
              .sort((a, b) => b.lastPurchaseDate.compareTo(a.lastPurchaseDate));
      }
    });
  }

  Future<void> _searchCustomers(String query) async {
    final results = await customerProvider.searchCustomers(query);
    setState(() {
      filteredCustomers = results;
    });
    _applySort();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: CustomAppBar(
        title: 'Customer Tracking',
        onBackPressed: () => Navigator.pop(context),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadCustomers,
            child: CustomScrollView(
              slivers: [
                // Search and filter section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Search bar
                        TextField(
                          controller: searchController,
                          onChanged: _searchCustomers,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search by name or phone',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(Icons.search,
                                color: AppColors.primary),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: AppColors.primary),
                                    onPressed: () {
                                      searchController.clear();
                                      _searchCustomers('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Sort options
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildSortChip('Recent', 'recent'),
                            _buildSortChip('Top Spending', 'spending'),
                            _buildSortChip('Most Transactions', 'transactions'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Summary stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildSummaryStats(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                // Customer list
                if (filteredCustomers.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text(
                            'No customers yet',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final customer = filteredCustomers[index];
                        return _buildCustomerCard(customer);
                      },
                      childCount: filteredCustomers.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = sortBy == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[400],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          sortBy = value;
          _applySort();
        });
      },
      backgroundColor: Colors.grey[800],
      selectedColor: AppColors.primary,
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.grey[700]!,
      ),
    );
  }

  Widget _buildSummaryStats() {
    final totalCustomers = filteredCustomers.length;
    final totalSpent =
        filteredCustomers.fold<double>(0, (sum, c) => sum + c.totalSpent);
    final avgSpent = totalCustomers > 0 ? totalSpent / totalCustomers : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatColumn('Total Customers', '$totalCustomers', Icons.people),
          _buildStatColumn('Total Spent', '₦${totalSpent.toStringAsFixed(0)}',
              Icons.payments),
          _buildStatColumn('Avg per Customer',
              '₦${avgSpent.toStringAsFixed(0)}', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    final lastPurchaseDaysAgo =
        DateTime.now().difference(customer.lastPurchaseDate).inDays;
    final lastPurchaseText = lastPurchaseDaysAgo == 0
        ? 'Today'
        : lastPurchaseDaysAgo == 1
            ? 'Yesterday'
            : '$lastPurchaseDaysAgo days ago';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: InkWell(
        onTap: () => _showCustomerDetails(customer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (customer.phone != null)
                          Text(
                            customer.phone!,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  // Customer rank badge
                  _buildCustomerBadge(customer),
                ],
              ),
              const SizedBox(height: 12),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Purchases', '${customer.totalTransactions}'),
                  _buildStatItem('Total Spent',
                      '₦${customer.totalSpent.toStringAsFixed(0)}'),
                  _buildStatItem('Avg Order',
                      '₦${customer.averageOrderValue.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 12),
              // Last purchase
              Text(
                'Last purchase: $lastPurchaseText',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              if (customer.notes != null && customer.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Notes: ${customer.notes}',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerBadge(CustomerModel customer) {
    String badge = '';
    Color color = Colors.grey;

    if (customer.totalSpent > 50000) {
      badge = 'VIP';
      color = Colors.amber;
    } else if (customer.totalSpent > 20000) {
      badge = 'Gold';
      color = Colors.orange;
    } else if (customer.totalTransactions >= 10) {
      badge = 'Loyal';
      color = AppColors.primary;
    }

    if (badge.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        badge,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showCustomerDetails(CustomerModel customer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (customer.phone != null)
                        Text(
                          customer.phone!,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Contact info
              if (customer.email != null ||
                  customer.phone != null ||
                  customer.address != null)
                _buildDetailSection('Contact Information', [
                  if (customer.email != null)
                    _buildDetailItem('Email', customer.email!),
                  if (customer.phone != null)
                    _buildDetailItem('Phone', customer.phone!),
                  if (customer.address != null)
                    _buildDetailItem('Address', customer.address!),
                ]),
              const SizedBox(height: 20),
              // Purchase stats
              _buildDetailSection('Purchase Statistics', [
                _buildDetailItem(
                    'Total Purchases', '${customer.totalTransactions}'),
                _buildDetailItem('Total Spent',
                    '₦${customer.totalSpent.toStringAsFixed(2)}'),
                _buildDetailItem('Average Order',
                    '₦${customer.averageOrderValue.toStringAsFixed(2)}'),
                _buildDetailItem(
                    'First Purchase', _formatDate(customer.firstPurchaseDate)),
                _buildDetailItem(
                    'Last Purchase', _formatDate(customer.lastPurchaseDate)),
              ]),
              if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildDetailSection('Notes', [
                  Text(
                    customer.notes!,
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

