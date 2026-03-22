import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/wholesale_provider.dart';

class WarehouseReportsScreen extends StatefulWidget {
  const WarehouseReportsScreen({super.key});

  @override
  State<WarehouseReportsScreen> createState() => _WarehouseReportsScreenState();
}

class _WarehouseReportsScreenState extends State<WarehouseReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _reportType = 'inventory'; // inventory, suppliers, transfers, trends

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WholesaleProvider>().loadProducts();
      context.read<WholesaleProvider>().loadPurchaseOrders();
      context.read<WholesaleProvider>().loadStockTransfers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Warehouse Reports'),
        elevation: 0,
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = context.read<WholesaleProvider>();
              provider.loadProducts();
              provider.loadPurchaseOrders();
              provider.loadStockTransfers();
            },
          ),
        ],
      ),
      body: Consumer<WholesaleProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Date Range Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From', style: AppTextStyles.caption),
                              Text(
                                  DateFormat('MMM dd, yyyy').format(_startDate),
                                  style: AppTextStyles.body2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _endDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('To', style: AppTextStyles.caption),
                              Text(DateFormat('MMM dd, yyyy').format(_endDate),
                                  style: AppTextStyles.body2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Report Type Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _ReportTypeChip(
                      label: 'Inventory',
                      isActive: _reportType == 'inventory',
                      onTap: () => setState(() => _reportType = 'inventory'),
                    ),
                    const SizedBox(width: 8),
                    _ReportTypeChip(
                      label: 'Suppliers',
                      isActive: _reportType == 'suppliers',
                      onTap: () => setState(() => _reportType = 'suppliers'),
                    ),
                    const SizedBox(width: 8),
                    _ReportTypeChip(
                      label: 'Transfers',
                      isActive: _reportType == 'transfers',
                      onTap: () => setState(() => _reportType = 'transfers'),
                    ),
                    const SizedBox(width: 8),
                    _ReportTypeChip(
                      label: 'Trends',
                      isActive: _reportType == 'trends',
                      onTap: () => setState(() => _reportType = 'trends'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Report Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: () {
                    switch (_reportType) {
                      case 'inventory':
                        return _InventoryReport(provider: provider);
                      case 'suppliers':
                        return _SuppliersReport(
                          purchaseOrders: provider.purchaseOrders,
                          startDate: _startDate,
                          endDate: _endDate,
                        );
                      case 'transfers':
                        return _TransfersReport(
                          transfers: provider.stockTransfers,
                          startDate: _startDate,
                          endDate: _endDate,
                        );
                      case 'trends':
                        return _TrendsReport(provider: provider);
                      default:
                        return const SizedBox();
                    }
                  }(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportTypeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ReportTypeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InventoryReport extends StatelessWidget {
  final WholesaleProvider provider;

  const _InventoryReport({required this.provider});

  @override
  Widget build(BuildContext context) {
    final products = provider.products;
    final totalValue = provider.getTotalInventoryValue();
    final lowStockProducts = provider.getLowStockProducts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Value',
                value: formatCurrency(totalValue, decimalDigits: 0),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total Items',
                value: '${provider.getTotalItems()}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Products',
                value: '${products.length}',
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Inventory by Category', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        ..._buildCategoryBreakdown(products),
        const SizedBox(height: 24),
        if (lowStockProducts.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Low Stock Alert (${lowStockProducts.length})',
                  style: AppTextStyles.heading3),
              const SizedBox(height: 12),
              ...lowStockProducts.map(
                (product) => _InventoryRow(
                  name: product.name,
                  quantity: '${product.quantity}/${product.reorderLevel}',
                  value: formatCurrency(
                    product.quantity * product.costPrice,
                    decimalDigits: 0,
                  ),
                  status: 'Low',
                  statusColor: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        const Text('Top Products by Value', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        ...products
            .asMap()
            .entries
            .toList()
            .sublist(0, (products.length > 5 ? 5 : products.length))
            .map(
              (entry) => _InventoryRow(
                name: entry.value.name,
                quantity: '${entry.value.quantity}',
                value: formatCurrency(
                  entry.value.quantity * entry.value.costPrice,
                  decimalDigits: 0,
                ),
                status: entry.key.toString(),
              ),
            ),
      ],
    );
  }

  List<Widget> _buildCategoryBreakdown(List<WholesaleProduct> products) {
    final categories = <String, List<WholesaleProduct>>{};
    for (var product in products) {
      categories.putIfAbsent(product.category, () => []);
      categories[product.category]!.add(product);
    }

    return categories.entries.map((entry) {
      final totalValue = entry.value.fold<double>(
        0,
        (sum, p) => sum + (p.quantity * p.costPrice),
      );
      return _InventoryRow(
        name: entry.key,
        quantity: '${entry.value.length} items',
        value: formatCurrency(totalValue, decimalDigits: 0),
      );
    }).toList();
  }
}

class _SuppliersReport extends StatelessWidget {
  final List<PurchaseOrder> purchaseOrders;
  final DateTime startDate;
  final DateTime endDate;

  const _SuppliersReport({
    required this.purchaseOrders,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final filteredOrders = purchaseOrders
        .where((o) =>
            o.createdAt.isAfter(startDate) &&
            o.createdAt.isBefore(endDate.add(const Duration(days: 1))))
        .toList();

    final supplierMap = <String, List<PurchaseOrder>>{};
    for (var order in filteredOrders) {
      supplierMap.putIfAbsent(order.supplier, () => []);
      supplierMap[order.supplier]!.add(order);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCard(
          label: 'Total Orders',
          value: '${filteredOrders.length}',
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        const Text('Supplier Performance', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        ...supplierMap.entries.map(
          (entry) {
            final orders = entry.value;
            final totalSpent = orders.fold<double>(0, (sum, o) => sum + o.total);
            final delivered = orders.where((o) => o.status == 'delivered').length;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: AppTextStyles.body1
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(orders.isEmpty ? 0 : (delivered / orders.length * 100)).toStringAsFixed(0)}% Delivered',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Orders: ${orders.length}', style: AppTextStyles.body2),
                      Text(
                        'Total: ${formatCurrency(totalSpent, decimalDigits: 0)}',
                        style: AppTextStyles.body2
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TransfersReport extends StatelessWidget {
  final List<StockTransfer> transfers;
  final DateTime startDate;
  final DateTime endDate;

  const _TransfersReport({
    required this.transfers,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTransfers = transfers
        .where((t) =>
            t.createdAt.isAfter(startDate) &&
            t.createdAt.isBefore(endDate.add(const Duration(days: 1))))
        .toList();

    final completed = filteredTransfers.where((t) => t.status == 'received').length;
    final pending = filteredTransfers.where((t) => t.status == 'pending').length;
    final inTransit = filteredTransfers.where((t) => t.status == 'in-transit').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total',
                value: '${filteredTransfers.length}',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Received',
                value: '$completed',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'In Transit',
                value: '$inTransit',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Transfer Status', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        _TransferStatusRow(
          status: 'Received',
          count: completed,
          percentage: filteredTransfers.isEmpty
              ? 0
              : (completed / filteredTransfers.length * 100),
          color: Colors.green,
        ),
        const SizedBox(height: 8),
        _TransferStatusRow(
          status: 'In Transit',
          count: inTransit,
          percentage: filteredTransfers.isEmpty
              ? 0
              : (inTransit / filteredTransfers.length * 100),
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        _TransferStatusRow(
          status: 'Pending',
          count: pending,
          percentage: filteredTransfers.isEmpty
              ? 0
              : (pending / filteredTransfers.length * 100),
          color: Colors.orange,
        ),
        const SizedBox(height: 24),
        const Text('Transfer Routes', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        ..._buildRouteSummary(filteredTransfers),
      ],
    );
  }

  List<Widget> _buildRouteSummary(List<StockTransfer> transfers) {
    final routeMap = <String, int>{};
    for (var transfer in transfers) {
      final route = '${transfer.fromWarehouse} -> ${transfer.toWarehouse}';
      routeMap[route] = (routeMap[route] ?? 0) + 1;
    }

    return routeMap.entries
        .map(
          (entry) => _InventoryRow(
            name: entry.key,
            quantity: '${entry.value} transfers',
            value: '',
          ),
        )
        .toList();
  }
}

class _TrendsReport extends StatelessWidget {
  final WholesaleProvider provider;

  const _TrendsReport({required this.provider});

  @override
  Widget build(BuildContext context) {
    final products = provider.products;
    final highTurnover =
        products.where((p) => p.quantity < p.reorderLevel * 0.5).length;
    final normalStock = products
        .where((p) =>
            p.quantity >= p.reorderLevel * 0.5 &&
            p.quantity <= p.reorderLevel * 2)
        .length;
    final overstock =
        products.where((p) => p.quantity > p.reorderLevel * 2).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stock Level Distribution
        const Text('Stock Level Distribution', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'High Turnover',
                value: '$highTurnover',
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Normal',
                value: '$normalStock',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Overstock',
                value: '$overstock',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Recommendations
        const Text('Recommendations', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        _RecommendationCard(
          title: 'Reorder Soon',
          description:
              'Reorder ${provider.getLowStockProducts().length} products to maintain stock levels',
          icon: Icons.warning,
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _RecommendationCard(
          title: 'Inventory Value',
          description:
              'Current inventory value: ₦${provider.getTotalInventoryValue().toStringAsFixed(0)}',
          icon: Icons.trending_up,
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _RecommendationCard(
          title: 'Total Items',
          description: 'Total items in stock: ${provider.getTotalItems()}',
          icon: Icons.inventory,
          color: Colors.green,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.body2.copyWith(color: color)),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  final String name;
  final String quantity;
  final String value;
  final String? status;
  final Color? statusColor;

  const _InventoryRow({
    required this.name,
    required this.quantity,
    required this.value,
    this.status,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.body2
                        .copyWith(fontWeight: FontWeight.bold)),
                Text(quantity, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (status != null && statusColor != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor!.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status!,
                style: TextStyle(
                  color: statusColor!,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            )
          else if (value.isNotEmpty)
            Text(value,
                style:
                    AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TransferStatusRow extends StatelessWidget {
  final String status;
  final int count;
  final double percentage;
  final Color color;

  const _TransferStatusRow({
    required this.status,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(status, style: AppTextStyles.body2),
            Text('$count (${percentage.toStringAsFixed(0)}%)',
                style:
                    AppTextStyles.body2.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _RecommendationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body1
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description,
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



