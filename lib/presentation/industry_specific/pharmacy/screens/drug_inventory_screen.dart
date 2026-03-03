import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/constants/routes.dart';


class DrugInventoryScreen extends StatefulWidget {
  const DrugInventoryScreen({super.key});

  @override
  State<DrugInventoryScreen> createState() => _DrugInventoryScreenState();
}

class _DrugInventoryScreenState extends State<DrugInventoryScreen> {
  String _filterOption = 'all'; // all, low_stock, expiring, expired
  String _searchQuery = '';
  final bool _sortByStock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reload data when screen appears
      final provider = context.read<PharmacyProvider>();
      final business = context.read<BusinessProvider>().currentBusiness;
      if (business != null) {
        provider.loadFromRepository(businessId: business.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drug Inventory'),
        backgroundColor: AppColors.pharmacy,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = context.read<PharmacyProvider>();
              final business = context.read<BusinessProvider>().currentBusiness;
              if (business != null) {
                provider.loadFromRepository(businessId: business.id);
              }
            },
          ),
        ],
      ),
      body: Consumer2<PharmacyProvider, BusinessProvider>(
        builder: (context, pharmacyProvider, businessProvider, child) {
          final business = businessProvider.currentBusiness;
          if (business == null) {
            return const Center(
              child: Text('No business selected'),
            );
          }

          // Get filtered drugs
          var drugs = pharmacyProvider.drugs;

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            drugs = pharmacyProvider.searchDrugs(_searchQuery);
          }

          // Apply status filter
          switch (_filterOption) {
            case 'low_stock':
              drugs = drugs.where((d) => d.stock <= 5).toList();
              break;
            case 'expiring':
              final cutoff = DateTime.now().add(const Duration(days: 30));
              drugs = drugs
                  .where((d) =>
                      d.expiry.isBefore(cutoff) &&
                      d.expiry.isAfter(DateTime.now()))
                  .toList();
              break;
            case 'expired':
              drugs = drugs
                  .where((d) => d.expiry.isBefore(DateTime.now()))
                  .toList();
              break;
          }

          // Apply sorting
          if (_sortByStock) {
            drugs.sort((a, b) => a.stock.compareTo(b.stock));
          }

          if (drugs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No drugs found',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Search and filter bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Search field
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search drugs...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: _filterOption == 'all',
                            onSelected: (_) =>
                                setState(() => _filterOption = 'all'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Low Stock'),
                            selected: _filterOption == 'low_stock',
                            onSelected: (_) =>
                                setState(() => _filterOption = 'low_stock'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Expiring Soon'),
                            selected: _filterOption == 'expiring',
                            onSelected: (_) =>
                                setState(() => _filterOption = 'expiring'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Expired'),
                            selected: _filterOption == 'expired',
                            onSelected: (_) =>
                                setState(() => _filterOption = 'expired'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Drug list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: drugs.length,
                  itemBuilder: (context, index) {
                    final drug = drugs[index];
                    final daysUntilExpiry =
                        drug.expiry.difference(DateTime.now()).inDays;
                    final isExpired = daysUntilExpiry < 0;
                    final isExpiringSoon =
                        daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
                    final isLowStock = drug.stock <= 5;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: _buildStatusIcon(
                            isExpired, isExpiringSoon, isLowStock),
                        title: Text(drug.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Batch: ${drug.batch}'),
                            Text(
                              'Exp: ${drug.expiry.toString().split(' ')[0]} ${isExpired ? '(EXPIRED)' : isExpiringSoon ? '($daysUntilExpiry days)' : ''}',
                              style: TextStyle(
                                color: isExpired
                                    ? Colors.red
                                    : isExpiringSoon
                                        ? Colors.orange
                                        : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Stock: ${drug.stock}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isLowStock ? Colors.red : Colors.green,
                                )),
                            Text('Price: ₦${drug.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () => _showDrugDetails(context, drug),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.pharmacy,
        onPressed: () => Navigator.pushNamed(context, Routes.pharmacyAddDrug),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusIcon(
      bool isExpired, bool isExpiringSoon, bool isLowStock) {
    if (isExpired) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.warning, color: Colors.red, size: 20),
      );
    } else if (isExpiringSoon) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.schedule, color: Colors.orange, size: 20),
      );
    } else if (isLowStock) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.trending_down, color: Colors.amber, size: 20),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
      );
    }
  }

  void _showDrugDetails(BuildContext context, dynamic drug) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(drug.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow('Batch Number', drug.batch),
            _buildDetailRow(
                'Expiry Date', drug.expiry.toString().split(' ')[0]),
            _buildDetailRow('Stock', '${drug.stock} units'),
            _buildDetailRow('Price', '₦${drug.price.toStringAsFixed(2)}'),
            _buildDetailRow('Inventory Value',
                '₦${(drug.price * drug.stock).toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, Routes.pharmacyEditDrug,
                          arguments: drug.id);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.remove),
                    label: const Text('Adjust Stock'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, Routes.pharmacyEditDrug,
                          arguments: drug.id);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }


}

