import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../data/repositories/customer_repository_impl.dart';
import '../../../providers/business_provider.dart';
import '../widgets/customer_card.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  late CustomerRepositoryImpl _repository;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = CustomerRepositoryImpl(firestore: FirebaseFirestore.instance);
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final businessId =
          context.read<BusinessProvider>().currentBusiness?.id ?? '';
      if (businessId.isEmpty) {
        setState(() {
          _error = 'No business selected';
          _isLoading = false;
        });
        return;
      }

      final customers = await _repository.getCustomers(businessId);
      setState(() {
        _customers = customers
            .cast<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load customers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomer(String customerId) async {
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
      await _repository.deleteCustomer(customerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Customer deleted')));
      _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete customer: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredCustomers = query.isEmpty
        ? _customers
        : _customers.where((customer) {
            final name = (customer['fullName'] ?? customer['name'] ?? '')
                .toString()
                .toLowerCase();
            final phone = (customer['phoneNumber'] ?? customer['phone'] ?? '')
                .toString()
                .toLowerCase();
            final email =
                (customer['email'] ?? '').toString().toLowerCase();
            return name.contains(query) ||
                phone.contains(query) ||
                email.contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.pushNamed(context, Routes.customersAdd),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search by name, phone, or email',
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: _customers.isEmpty
                          ? const Center(child: Text('No customers yet'))
                          : filteredCustomers.isEmpty
                              ? const Center(
                                  child: Text('No customers match your search'),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredCustomers.length,
                                  itemBuilder: (context, index) {
                                    final customer = filteredCustomers[index];
                                    final id = customer['id'] ?? '';
                                    final name = customer['fullName'] ??
                                        customer['name'] ??
                                        'Unknown';
                                    final phone = customer['phoneNumber'] ??
                                        customer['phone'] ??
                                        'N/A';
                                    final totalPurchases =
                                        customer['totalPurchases'] ?? 0;

                                    return CustomerCard(
                                      name: name,
                                      phone: phone,
                                      totalPurchases: 'NGN $totalPurchases',
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        Routes.customerDetails,
                                        arguments: {'customerId': id},
                                      ),
                                      onDelete: id.isNotEmpty
                                          ? () => _deleteCustomer(id)
                                          : null,
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
    );
  }
}
