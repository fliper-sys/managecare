import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../widgets/report_theme.dart';

class CustomerReportScreen extends StatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  bool _loading = true;
  String? _lastBusinessId;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _load(String? businessId) async {
    setState(() => _loading = true);
    await context.read<ReportsProvider>().generateCustomerReport(businessId: businessId);
    setState(() => _loading = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final businessId = context.read<BusinessProvider>().currentBusiness?.id ??
        context.read<AuthProvider>().currentUser?.businessId;
    if (businessId != null && businessId.isNotEmpty && businessId != _lastBusinessId) {
      _lastBusinessId = businessId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(businessId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReportsProvider>();
    return Scaffold(
      appBar: AppBar(
          title: const Text('Customer Report'),
          elevation: 0,
          backgroundColor: Colors.transparent),
      backgroundColor: context.reportBackground,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customers', style: AppTextStyles.heading2),
                  const SizedBox(height: 12),
                  if (rp.customerReports.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No customer transactions found for this business yet.',
                          style: AppTextStyles.body2Secondary,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                  Expanded(
                    child: ListView.separated(
                      itemCount: rp.customerReports.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = rp.customerReports[i];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          c.customerName.isNotEmpty
                                              ? c.customerName
                                              : c.customerId,
                                          style: AppTextStyles.heading5),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Orders: ${c.totalOrders} - Spent: ${formatCurrency(c.totalSpent)} - Avg: ${formatCurrency(c.averageOrderValue)}',
                                        style: AppTextStyles.body2Secondary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      elevation: 0),
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('View'),
                                  onPressed: () async {
                                    final sales = await context
                                        .read<ReportsProvider>()
                                        .getCustomerTransactions(c.customerId);
                                    if (!mounted) return;
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(
                                            'Transactions for ${c.customerName}'),
                                        content: SizedBox(
                                          width: 700,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: sales.length,
                                            itemBuilder: (context, idx) {
                                              final s = sales[idx];
                                              final items =
                                                  (s['items'] as List?) ?? [];
                                              return Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                              DateTime.tryParse(
                                                                          s['createdAt']?.toString() ??
                                                                              '')
                                                                      ?.toLocal()
                                                                      .toString() ??
                                                                  s['createdAt']
                                                                      ?.toString() ??
                                                                  '',
                                                              style:
                                                                  AppTextStyles
                                                                      .caption),
                                                          Text(
                                                              formatCurrency(((s['totalAmount'] ?? s['total'] ?? 0) as num).toDouble()),
                                                              style: AppTextStyles
                                                                  .captionBold),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 6,
                                                        children:
                                                            items.map((it) {
                                                          final iname = (it
                                                                  is Map)
                                                              ? (it['name'] ??
                                                                      it['productName'] ??
                                                                      it['title'] ??
                                                                      '')
                                                                  .toString()
                                                              : it.toString();
                                                          final iqty = (it
                                                                  is Map)
                                                              ? (it['quantity'] ??
                                                                      it['qty'] ??
                                                                      1)
                                                                  .toString()
                                                              : '1';
                                                          return Chip(
                                                              label: Text(
                                                                  '$iname x$iqty'));
                                                        }).toList(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Close'))
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}


