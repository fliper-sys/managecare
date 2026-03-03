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
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = CustomerRepositoryImpl(firestore: FirebaseFirestore.instance);
    _loadCustomers();
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

  @override
  Widget build(BuildContext context) {
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
              : _customers.isEmpty
                  ? const Center(child: Text('No customers yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) {
                        final customer = _customers[index];
                        final id = customer['id'] ?? '';
                        final name = customer['fullName'] ??
                            customer['name'] ??
                            'Unknown';
                        final phone = customer['phoneNumber'] ??
                            customer['phone'] ??
                            'N/A';
                        final totalPurchases = customer['totalPurchases'] ?? 0;

                        return CustomerCard(
                          name: name,
                          phone: phone,
                          totalPurchases: '₦$totalPurchases',
                          onTap: () => Navigator.pushNamed(
                            context,
                            Routes.customerDetails,
                            arguments: {'customerId': id},
                          ),
                        );
                      },
                    ),
    );
  }
}

