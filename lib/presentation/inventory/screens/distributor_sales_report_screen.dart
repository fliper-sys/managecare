import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/distributor_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/retail_provider.dart';
import '../utils/distributor_sales_analytics.dart';

class DistributorSalesReportScreen extends StatefulWidget {
  const DistributorSalesReportScreen({super.key});

  @override
  State<DistributorSalesReportScreen> createState() => _DistributorSalesReportScreenState();
}

class _DistributorSalesReportScreenState extends State<DistributorSalesReportScreen> {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _distributors = [];
  List<Map<String, dynamic>> _sales = [];
  String _searchText = '';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
      if (businessId.isEmpty) {
        throw Exception('No business selected');
      }

      final repository = DistributorRepository();
      final distributors = await repository.getDistributors(businessId);
      final sales = await repository.getDistributorSales(businessId);

      setState(() {
        _distributors = distributors;
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddDistributorDialog() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No business selected')));
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final contactController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Register Distributor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Distributor Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact Person (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Distributor name is required')));
      return;
    }

    try {
      final repository = DistributorRepository();
      await repository.addDistributor(
        businessId: businessId,
        name: name,
        phone: phoneController.text.trim(),
        contactPerson: contactController.text.trim(),
        notes: notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Distributor registered successfully')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to register distributor: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showDistributorSaleDialog() async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No business selected')));
      return;
    }

    final repository = DistributorRepository();
    final distributors = await repository.getDistributors(businessId);
    await context.read<RetailProvider>().loadProducts();
    final products = context
        .read<RetailProvider>()
        .products
        .map((product) => <String, dynamic>{
              'id': product.id,
              'name': product.name,
              'price': product.price,
              'distributorPrice': product.distributorPrice,
              'distributorDiscountPercent': product.distributorDiscountPercent,
            })
        .toList();

    if (!mounted) return;

    String? selectedProductId;
    String? selectedDistributorId;
    String? selectedDistributorName;
    final quantityController = TextEditingController(text: '1');
    final notesController = TextEditingController();
    final newDistributorController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, dialogSetState) {
            return AlertDialog(
              title: const Text('Record Distributor Sale'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (products.isEmpty)
                      const Text('No inventory products found. Add products before recording distributor sales.')
                    else
                      DropdownButtonFormField<String>(
                        value: selectedProductId,
                        decoration: const InputDecoration(labelText: 'Product'),
                        items: products.map((product) {
                          return DropdownMenuItem<String>(
                            value: product['id']?.toString() ?? '',
                            child: Text(product['name']?.toString() ?? 'Unnamed product'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          dialogSetState(() {
                            selectedProductId = value;
                          });
                        },
                      ),
                    if (selectedProductId != null) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final selectedProduct = products.firstWhere(
                          (entry) =>
                              (entry['id']?.toString() ?? '') ==
                              selectedProductId,
                          orElse: () => <String, dynamic>{},
                        );
                        final distributorPrice =
                            (selectedProduct['distributorPrice'] as num?)
                                ?.toDouble();
                        final price =
                            distributorPrice ??
                                (selectedProduct['price'] as num?)
                                    ?.toDouble() ??
                                0.0;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Distributor unit price: ₦${price.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    if (distributors.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedDistributorId,
                        decoration: const InputDecoration(labelText: 'Distributor'),
                        items: distributors.map((distributor) {
                          return DropdownMenuItem<String>(
                            value: distributor['id']?.toString() ?? '',
                            child: Text(distributor['name']?.toString() ?? 'Unnamed distributor'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          dialogSetState(() {
                            selectedDistributorId = value;
                            selectedDistributorName = distributors.firstWhere(
                              (entry) => (entry['id']?.toString() ?? '') == value,
                              orElse: () => <String, dynamic>{},
                            )['name']
                                ?.toString();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Or enter a new distributor name below.'),
                    ],
                    if (distributors.isEmpty) const Text('Register a new distributor below.'),
                    TextField(
                      controller: newDistributorController,
                      decoration: const InputDecoration(labelText: 'New distributor name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Record Sale')),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    if (products.isEmpty) return;

    final productId = selectedProductId?.trim() ?? '';
    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a product')));
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than zero')));
      return;
    }

    String distributorId = selectedDistributorId ?? '';
    String distributorName = selectedDistributorName ?? '';
    if (distributorId.isEmpty) {
      distributorName = newDistributorController.text.trim();
      if (distributorName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Distributor name is required')));
        return;
      }
      distributorId = await repository.addDistributor(businessId: businessId, name: distributorName);
    }

    final product = products.firstWhere(
      (entry) => (entry['id']?.toString() ?? '') == productId,
      orElse: () => <String, dynamic>{},
    );
    if (product.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected product not found')));
      return;
    }

    final distributorPrice = (product['distributorPrice'] as num?)?.toDouble();
    final unitPrice =
        distributorPrice ?? (product['price'] as num?)?.toDouble() ?? 0.0;
    final discountPercent = distributorPrice == null
        ? (product['distributorDiscountPercent'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final salesRepId = context.read<AuthProvider>().currentUser?.id;
    final salesRepName = context.read<AuthProvider>().currentUser?.fullName ?? context.read<AuthProvider>().currentUser?.email ?? '';

    try {
      await repository.recordDistributorSale(
        businessId: businessId,
        distributorId: distributorId,
        distributorName: distributorName,
        productId: productId,
        productName: product['name']?.toString() ?? 'Unknown product',
        quantity: quantity,
        unitPrice: unitPrice,
        discountPercent: discountPercent,
        salesRepId: salesRepId,
        salesRepName: salesRepName,
        notes: notesController.text.trim(),
      );
      if (!mounted) return;
      final discountedPrice = unitPrice * (1 - discountPercent / 100);
      final totalAmount = discountedPrice * quantity;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Distributor sale recorded for ₦${totalAmount.toStringAsFixed(2)}')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to record distributor sale: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  void _clearDateRange() {
    setState(() => _range = null);
  }

  List<Map<String, dynamic>> _filteredSales() {
    final query = _searchText.trim().toLowerCase();
    return _sales.where((sale) {
      final distributor = (sale['distributorName'] ?? '').toString().toLowerCase();
      final product = (sale['productName'] ?? '').toString().toLowerCase();
      final notes = (sale['notes'] ?? '').toString().toLowerCase();
      final matchesSearch = query.isEmpty || distributor.contains(query) || product.contains(query) || notes.contains(query);

      final createdAt = sale['createdAt'];
      DateTime? date;
      if (createdAt is String) {
        date = DateTime.tryParse(createdAt);
      } else if (createdAt is DateTime) {
        date = createdAt;
      }

      var matchesDate = true;
      if (date != null && _range != null) {
        final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
        final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
        matchesDate = !date.isBefore(start) && !date.isAfter(end);
      }

      return matchesSearch && matchesDate;
    }).toList();
  }

  Future<void> _showDistributorHistory(Map<String, dynamic> distributor) async {
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ?? '';
    if (businessId.isEmpty) return;

    final sales = await DistributorRepository().getDistributorSales(
      businessId,
      distributorId: distributor['id']?.toString(),
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${distributor['name']?.toString() ?? 'Distributor'} Sales'),
          content: SizedBox(
            width: double.maxFinite,
            child: sales.isEmpty
                ? const Text('No sales recorded for this distributor yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: sales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final sale = sales[index];
                      final createdAt = sale['createdAt'];
                      final parsedCreatedAt = createdAt is String ? DateTime.tryParse(createdAt) : null;
                      final when = parsedCreatedAt != null
                          ? parsedCreatedAt.toLocal().toString().split('.').first
                          : createdAt?.toString() ?? '—';
                      return ListTile(
                        title: Text(sale['productName']?.toString() ?? 'Unknown product'),
                        subtitle: Text('Qty ${sale['quantity'] ?? 0} • ₦${(sale['totalAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}'),
                        trailing: Text(when, style: AppTextStyles.caption),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSales = _filteredSales();
    final analytics = DistributorSalesAnalytics.summarize(filteredSales);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributor Sales'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Register distributor',
            onPressed: _showAddDistributorDialog,
          ),
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Record distributor sale',
            onPressed: _showDistributorSaleDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error, style: AppTextStyles.body1),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Search distributor or product',
                        ),
                        onChanged: (value) => setState(() => _searchText = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDateRange,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                _range == null
                                    ? 'Filter by date'
                                    : '${DateFormat.yMMMd().format(_range!.start)} → ${DateFormat.yMMMd().format(_range!.end)}',
                              ),
                            ),
                          ),
                          if (_range != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _clearDateRange,
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear date filter',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Distributor sales summary', style: AppTextStyles.heading4),
                            const SizedBox(height: 8),
                            Text('Sales: ${analytics.saleCount}'),
                            Text('Items sold: ${analytics.totalQuantity}'),
                            Text('Revenue: ₦${analytics.totalAmount.toStringAsFixed(2)}'),
                            Text('Distributors: ${analytics.distributorCount}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Distributors', style: AppTextStyles.heading4),
                      const SizedBox(height: 12),
                      if (_distributors.isEmpty)
                        Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: ListTile(
                            title: const Text('No distributors registered yet'),
                            subtitle: const Text('Register a distributor using the add button above.'),
                            trailing: TextButton(
                              onPressed: _showAddDistributorDialog,
                              child: const Text('Register'),
                            ),
                          ),
                        )
                      else
                        ..._distributors.map((distributor) {
                          return Card(
                            child: ListTile(
                              title: Text(distributor['name']?.toString() ?? 'Unnamed'),
                              subtitle: Text('Phone: ${distributor['phone'] ?? 'N/A'}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showDistributorHistory(distributor),
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 24),
                      const Text('Sales History', style: AppTextStyles.heading4),
                      const SizedBox(height: 12),
                      if (filteredSales.isEmpty)
                        const Center(child: Text('No distributor sales yet'))
                      else
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filteredSales.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final sale = filteredSales[index];
                            final createdAt = sale['createdAt'];
                            final parsedCreatedAt = createdAt is String ? DateTime.tryParse(createdAt) : null;
                            final label = parsedCreatedAt != null
                                ? parsedCreatedAt.toLocal().toString().split('.').first
                                : createdAt?.toString() ?? '—';
                            final total = (sale['totalAmount'] as num?)?.toDouble() ?? 0.0;
                            return Card(
                              child: ListTile(
                                title: Text(sale['productName']?.toString() ?? 'Unknown product'),
                                subtitle: Text(
                                  '${sale['distributorName'] ?? 'Unknown distributor'} • Qty ${sale['quantity'] ?? 0} • ${sale['discountPercent'] ?? 0}% off',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₦${total.toStringAsFixed(2)}', style: AppTextStyles.heading5),
                                        Text(label, style: AppTextStyles.caption),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        final saleId = sale['id']?.toString() ?? '';
                                        if (value == 'view') {
                                          if (saleId.isNotEmpty) {
                                            Navigator.pushNamed(context, Routes.salesReceipt, arguments: {'saleId': saleId});
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt not available')));
                                          }
                                        } else if (value == 'delete') {
                                          final confirm = await showDialog<bool?>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete sale'),
                                              content: const Text('Are you sure you want to delete this sale? This will restock the items.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                              ],
                                            ),
                                          );
                                          if (confirm == true && saleId.isNotEmpty) {
                                            try {
                                              final reports = context.read<ReportsProvider>();
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleting sale...')));
                                              final res = await reports.deleteSale(saleId);
                                              if (res == null || res['success'] != true) {
                                                final msg = res != null && res['error'] != null ? res['error'].toString() : 'Delete failed';
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete sale: $msg'), backgroundColor: Colors.red));
                                              } else {
                                                setState(() {
                                                  _sales.removeAt(index);
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted')));
                                              }
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e'), backgroundColor: Colors.red));
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'view', child: Text('View Receipt')),
                                        const PopupMenuItem(value: 'delete', child: Text('Delete Sale')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}
