import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../widgets/custom_button.dart';

class BarTabsScreen extends StatefulWidget {
  const BarTabsScreen({super.key});

  @override
  State<BarTabsScreen> createState() => _BarTabsScreenState();
}

class _BarTabsScreenState extends State<BarTabsScreen> {
  String _filter = 'open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final businessId =
          context.read<BusinessProvider>().currentBusiness?.id ?? '';
      if (businessId.isNotEmpty) {
        context.read<DrinkProvider>().setBusinessId(businessId);
      }
    });
  }

  Future<String?> _selectPaymentMethod() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Cash'),
              onTap: () => Navigator.pop(ctx, 'Cash'),
            ),
            ListTile(
              title: const Text('Debit/Credit Card'),
              onTap: () => Navigator.pop(ctx, 'Debit/Credit Card'),
            ),
            ListTile(
              title: const Text('Digital Wallet'),
              onTap: () => Navigator.pop(ctx, 'Digital Wallet'),
            ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConvertInvoice(BarInvoice invoice) async {
    final paymentMethod = await _selectPaymentMethod();
    if (paymentMethod == null) return;

    final auth = context.read<AuthProvider>();
    final provider = context.read<DrinkProvider>();

    try {
      final saleMap = await provider.convertInvoiceToSale(
        invoice.id,
        paymentMethod,
        workerId: auth.currentUser?.id,
        workerName: auth.currentUser?.fullName,
      );

      if (!mounted) return;
      await ReceiptManager.handlePostSale(context, saleMap);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${invoice.invoiceNumber} converted to sale successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to convert invoice: $e')),
      );
    }
  }

  Future<void> _handleCancelInvoice(BarInvoice invoice) async {
    final shouldCancel = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cancel invoice?'),
            content: Text(
                'This will keep ${invoice.invoiceNumber} in history but mark it as cancelled.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cancel invoice'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldCancel) return;

    try {
      await context.read<DrinkProvider>().cancelInvoice(invoice.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${invoice.invoiceNumber} marked as cancelled'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel invoice: $e')),
      );
    }
  }

  List<BarInvoice> _filterInvoices(List<BarInvoice> invoices) {
    switch (_filter) {
      case 'converted':
        return invoices.where((invoice) => invoice.status == 'converted').toList();
      case 'cancelled':
        return invoices.where((invoice) => invoice.status == 'cancelled').toList();
      case 'all':
        return invoices;
      case 'open':
      default:
        return invoices.where((invoice) => invoice.status == 'open').toList();
    }
  }

  String _formatInvoiceSubtitle(BarInvoice invoice) {
    final details = <String>[];
    if (invoice.tableLabel != null && invoice.tableLabel!.trim().isNotEmpty) {
      details.add(invoice.tableLabel!.trim());
    }
    if (invoice.customerName.trim().isNotEmpty &&
        invoice.customerName != 'Walk-in Customer') {
      details.add(invoice.customerName);
    }
    details.add('${invoice.itemCount} items');
    return details.join(' • ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'converted':
        return AppColors.success;
      case 'cancelled':
        return Colors.red;
      case 'open':
      default:
        return Colors.orange;
    }
  }

  void _showInvoiceDetails(BarInvoice invoice) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.invoiceNumber,
                        style: AppTextStyles.heading5.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(invoice.status.toUpperCase()),
                      backgroundColor: _statusColor(invoice.status).withOpacity(0.12),
                      labelStyle: TextStyle(
                        color: _statusColor(invoice.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatInvoiceSubtitle(invoice),
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Created: ${invoice.createdAt.toLocal().toString().split('.').first}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (invoice.notes != null && invoice.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Notes', style: AppTextStyles.subtitle2),
                  const SizedBox(height: 4),
                  Text(invoice.notes!),
                ],
                const SizedBox(height: 16),
                Text(
                  'Items',
                  style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...invoice.lines.map((line) {
                  final drink =
                      context.read<DrinkProvider>().getDrinkById(line.drinkId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(drink?.name ?? 'Unknown drink'),
                    subtitle: Text('${line.quantityBottles} bottle(s)'),
                    trailing: Text(
                      '₦${line.lineTotal().toStringAsFixed(2)}',
                      style: AppTextStyles.subtitle2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
                const Divider(height: 24),
                _SummaryRow(
                  label: 'Subtotal',
                  value: '₦${invoice.subtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Tax',
                  value: '₦${invoice.tax.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Discount',
                  value: '₦${invoice.discount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Total',
                  value: '₦${invoice.total.toStringAsFixed(2)}',
                  isTotal: true,
                ),
                const SizedBox(height: 16),
                if (invoice.status == 'open') ...[
                  CustomButton(
                    text: 'Convert to Sale',
                    backgroundColor: Colors.green.shade600,
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _handleConvertInvoice(invoice);
                    },
                  ),
                  const SizedBox(height: 8),
                  CustomButton(
                    text: 'Cancel Invoice',
                    type: ButtonType.outlined,
                    backgroundColor: Colors.red.shade300,
                    textColor: Colors.red.shade700,
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _handleCancelInvoice(invoice);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                CustomButton(
                  text: 'Close',
                  type: ButtonType.outlined,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DrinkProvider>(
      builder: (context, provider, _) {
        final invoices = _filterInvoices(provider.getInvoiceHistory());

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tabs & Invoices'),
            actions: [
              IconButton(
                tooltip: 'Open POS',
                icon: const Icon(Icons.point_of_sale),
                onPressed: () => Navigator.pushNamed(context, Routes.drinkPos),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Open',
                      selected: _filter == 'open',
                      onTap: () => setState(() => _filter = 'open'),
                    ),
                    _FilterChip(
                      label: 'Converted',
                      selected: _filter == 'converted',
                      onTap: () => setState(() => _filter = 'converted'),
                    ),
                    _FilterChip(
                      label: 'Cancelled',
                      selected: _filter == 'cancelled',
                      onTap: () => setState(() => _filter = 'cancelled'),
                    ),
                    _FilterChip(
                      label: 'All',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: invoices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: AppColors.border,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filter == 'open'
                                    ? 'No open tabs or invoices'
                                    : 'No invoices in this view',
                                style: AppTextStyles.heading5,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Saved invoices stay here until payment happens, so workers can convert them to sales without re-entering the order.',
                                style: AppTextStyles.body2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              CustomButton(
                                text: 'Create New Invoice',
                                onPressed: () =>
                                    Navigator.pushNamed(context, Routes.drinkPos),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: invoices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final invoice = invoices[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _showInvoiceDetails(invoice),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            invoice.invoiceNumber,
                                            style:
                                                AppTextStyles.subtitle1.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Chip(
                                          label: Text(
                                            invoice.status.toUpperCase(),
                                          ),
                                          backgroundColor: _statusColor(
                                            invoice.status,
                                          ).withOpacity(0.12),
                                          labelStyle: TextStyle(
                                            color: _statusColor(invoice.status),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatInvoiceSubtitle(invoice),
                                      style: AppTextStyles.body2.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          invoice.createdAt
                                              .toLocal()
                                              .toString()
                                              .split('.')
                                              .first,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '₦${invoice.total.toStringAsFixed(2)}',
                                          style: AppTextStyles.subtitle1.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.brown.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (invoice.status == 'open') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Convert to Sale',
                                              backgroundColor:
                                                  Colors.green.shade600,
                                              onPressed: () =>
                                                  _handleConvertInvoice(invoice),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: CustomButton(
                                              text: 'Cancel',
                                              type: ButtonType.outlined,
                                              backgroundColor:
                                                  Colors.red.shade300,
                                              textColor: Colors.red.shade700,
                                              onPressed: () =>
                                                  _handleCancelInvoice(invoice),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)
        : AppTextStyles.body2;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
