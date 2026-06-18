import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../core/constants/routes.dart';
import '../../../services/inventory_export_service.dart';
import '../widgets/report_card.dart';
import '../widgets/report_theme.dart';

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  late TextEditingController _searchController;
  String? _lastBusinessId;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
          authProvider.currentUser?.businessId;
      if (businessId != null && businessId.isNotEmpty) {
        _loadReport(businessId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport(String businessId) async {
    _lastBusinessId = businessId;
    await context.read<ReportsProvider>().generateInventoryReport(businessId: businessId);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final businessProvider = context.watch<BusinessProvider>();
    final currentBusinessId = businessProvider.currentBusiness?.id ??
        authProvider.currentUser?.businessId;
    if (currentBusinessId == null || currentBusinessId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inventory Report'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('No business selected',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.businessSelection),
                child: const Text('Select Business'),
              ),
            ],
          ),
        ),
      );
    }
    if (_lastBusinessId != currentBusinessId) {
      if (currentBusinessId.isNotEmpty) {
        Future.microtask(() => _loadReport(currentBusinessId));
      }
    }
    return Scaffold(
      backgroundColor: context.reportBackground,
      appBar: AppBar(
        title: const Text('Inventory Report'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _showExportOptions(context),
          ),
        ],
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, reportsProvider, _) {
          if (reportsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (reportsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${reportsProvider.error}'),
                ],
              ),
            );
          }

          final inventorySummary = reportsProvider.getInventorySummary();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by product name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),

                // Inventory Summary
                const Text('Inventory Summary', style: AppTextStyles.heading2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ReportCard(
                        title: 'Total Items',
                        value: '${inventorySummary['totalItems']}',
                        icon: Icons.inventory_2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ReportCard(
                        title: 'Low Stock',
                        value: '${inventorySummary['lowStockItems']}',
                        icon: Icons.warning,
                        color: const Color.fromARGB(255, 63, 20, 77),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ReportCard(
                        title: 'Total Value',
                        value:
                            '₦${(inventorySummary['inventoryValue'] as double).toStringAsFixed(2)}',
                        icon: Icons.attach_money,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ReportCard(
                        title: 'Products',
                        value: '${reportsProvider.inventoryReports.length}',
                        icon: Icons.category,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Low Stock Alert
                if ((inventorySummary['lowStockItems'] as int) > 0)
                  _buildLowStockAlert(reportsProvider),
                const SizedBox(height: 24),

                // Inventory Value Chart
                _buildInventoryValueChart(reportsProvider),
                const SizedBox(height: 24),

                // Detailed Inventory Table
                _buildInventoryTable(reportsProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLowStockAlert(ReportsProvider reportsProvider) {
    final lowStockItems =
        reportsProvider.inventoryReports.where((r) => r.isLowStock).toList();

    return Card(
      color: AppColors.warning.withAlpha(30),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Low Stock Items', style: AppTextStyles.heading3),
              ],
            ),
            const SizedBox(height: 12),
            ...lowStockItems.take(5).map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Current: ${item.quantity} units',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Reorder',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryValueChart(ReportsProvider reportsProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventory Value Distribution',
                style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildValueChart(reportsProvider.inventoryReports),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueChart(List<InventoryReport> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final topItems = data.take(7).toList();
    // Note: maxValue calculation commented out as it's not currently used

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        topItems.length,
        (index) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.5)
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                  child: Tooltip(
                    message:
                        '₦${topItems[index].totalValue.toStringAsFixed(2)}',
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'P${topItems[index].productId}',
                style: AppTextStyles.caption
                    .copyWith(color: context.reportMutedText, fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryTable(ReportsProvider reportsProvider) {
    final filteredInventory = _filteredInventoryReports(reportsProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Inventory Details', style: AppTextStyles.heading2),
                if (filteredInventory.length !=
                    reportsProvider.inventoryReports.length)
                  Text(
                    '${filteredInventory.length} of ${reportsProvider.inventoryReports.length}',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredInventory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No inventory items matching your search'),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                      AppColors.primary.withOpacity(0.1)),
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Quantity')),
                    DataColumn(label: Text('Unit Price')),
                    DataColumn(label: Text('Cost')),
                    DataColumn(label: Text('Profit/Unit')),
                    DataColumn(label: Text('Profit Total')),
                    DataColumn(label: Text('Total Value')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: filteredInventory
                      .map(
                        (report) => DataRow(
                          cells: [
                            DataCell(Text(report.productName)),
                            DataCell(Text('${report.quantity} ${report.unit}')),
                            DataCell(Text(
                                '₦${report.unitPrice.toStringAsFixed(2)}')),
                            DataCell(Text(
                                '₦${report.costPrice.toStringAsFixed(2)}')),
                            DataCell(Text(
                                '₦${report.profitPerUnit.toStringAsFixed(2)}')),
                            DataCell(Text(
                                '₦${report.totalProfit.toStringAsFixed(2)}')),
                            DataCell(Text(
                                '₦${report.totalValue.toStringAsFixed(2)}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: report.isLowStock
                                      ? AppColors.warning.withOpacity(0.2)
                                      : AppColors.success
                                          .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  report.isLowStock ? 'Low' : 'OK',
                                  style: TextStyle(
                                    color: report.isLowStock
                                        ? AppColors.warning
                                        : AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<InventoryReport> _filteredInventoryReports(
    ReportsProvider reportsProvider,
  ) {
    return reportsProvider.inventoryReports
        .where(
          (report) => report.productName
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()),
        )
        .toList();
  }

  void _showExportOptions(BuildContext context) {
    final filteredInventory =
        _filteredInventoryReports(context.read<ReportsProvider>());

    if (filteredInventory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No inventory items available to export')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export As',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _exportInventory(
                  context,
                  filteredInventory,
                  asPdf: false,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _exportInventory(
                  context,
                  filteredInventory,
                  asPdf: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportInventory(
    BuildContext context,
    List<InventoryReport> reports, {
    required bool asPdf,
  }) async {
    final businessName =
        this.context.read<BusinessProvider>().currentBusiness?.name ??
            'Manage Care';

    final exportItems = reports
        .map(
          (report) => <String, dynamic>{
            'id': report.productId,
            'name': report.productName,
            'category': 'Inventory',
            'quantity': report.quantity,
            'minStock': report.reorderLevel,
            'price': report.unitPrice,
            'costPrice': report.costPrice,
            'unit': report.unit,
          },
        )
        .toList();

    try {
      final result = asPdf
          ? await InventoryExportService.exportPdf(
              items: exportItems,
              businessName: businessName,
              fileBaseName: 'Inventory_Report',
            )
          : await InventoryExportService.exportCsv(
              items: exportItems,
              businessName: businessName,
              fileBaseName: 'Inventory_Report',
            );

      if (!mounted) return;
      final format = asPdf ? 'PDF' : 'CSV';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inventory report exported as $format: ${result.fileName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export inventory report: $e')),
      );
    }
  }
}

