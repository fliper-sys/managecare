import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/business_provider.dart';
import '../../../../providers/drink_provider.dart';
import '../../../../providers/receipt_settings_provider.dart';
import '../../../../services/esc_pos_receipt_generator.dart';
import '../../../../services/pdf_invoice_generator.dart';
import '../../../../services/receipt_manager.dart';
import '../../../../services/thermal_printer_manager.dart';
import '../../../../services/thermal_printing_service.dart';
import '../../../../services/web_download.dart' as web_download;
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
      await ReceiptManager.handlePostSale(
        context,
        saleMap,
        invoiceGeneratedBeforeCheckout: true,
      );
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

  Future<void> _handleEditInvoice(BarInvoice invoice) async {
    await Navigator.pushNamed(
      context,
      Routes.drinkPos,
      arguments: {'invoiceId': invoice.id},
    );
  }

  Future<void> _handleReopenInvoice(BarInvoice invoice) async {
    try {
      await context.read<DrinkProvider>().reopenInvoice(invoice.id);
      if (!mounted) return;
      setState(() => _filter = 'open');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${invoice.invoiceNumber} reopened for editing'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reopen invoice: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _invoiceItems(
    BarInvoice invoice,
    DrinkProvider provider,
  ) {
    return invoice.lines.map((line) {
      final drink = provider.getDrinkById(line.drinkId);
      final name = drink?.name ?? 'Unknown drink';
      return {
        'productId': line.drinkId,
        'name': name,
        'productName': name,
        'menuItemName': name,
        'quantity': line.quantityBottles,
        'price': line.unitPrice,
        'unitPrice': line.unitPrice,
        'subtotal': line.lineTotal(),
        'total': line.lineTotal(),
        'selectedOptions': line.modifiers
            .map((modifier) => {
                  'choiceName': modifier.name,
                  'price': modifier.price,
                })
            .toList(),
      };
    }).toList();
  }

  Future<Uint8List> _buildInvoicePdf(BarInvoice invoice) {
    final business = context.read<BusinessProvider>().currentBusiness;
    final auth = context.read<AuthProvider>();
    final provider = context.read<DrinkProvider>();
    final notes = [
      if ((invoice.customerPhone ?? '').trim().isNotEmpty)
        'Customer phone: ${invoice.customerPhone!.trim()}',
      if ((invoice.tableLabel ?? '').trim().isNotEmpty)
        'Table/Tab: ${invoice.tableLabel!.trim()}',
      if ((invoice.notes ?? '').trim().isNotEmpty) invoice.notes!.trim(),
    ].join('\n');

    return PdfInvoiceGenerator.generateInvoicePdfBytes(
      businessName: business?.name ?? 'Bar',
      invoiceNumber: invoice.invoiceNumber,
      invoiceDate: invoice.createdAt,
      cartItems: _invoiceItems(invoice, provider),
      subtotal: invoice.subtotal,
      tax: invoice.tax,
      discount: invoice.discount,
      total: invoice.total,
      customerName: invoice.customerName,
      customerEmail: invoice.customerEmail,
      businessAddress: business?.address,
      businessPhone: business?.phone,
      businessEmail: business?.email,
      cashierName: invoice.workerName ?? auth.currentUser?.fullName,
      businessLogoUrl: business?.photoUrl ?? business?.logoUrl,
      subscriptionTier: business?.subscriptionTier,
      businessClass: business?.businessClass,
      notes: notes.trim().isEmpty ? null : notes,
    );
  }

  Future<void> _shareInvoice(BarInvoice invoice) async {
    try {
      final pdfBytes = await _buildInvoicePdf(invoice);
      final filename =
          PdfInvoiceGenerator.getInvoiceFilename(invoice.invoiceNumber);

      if (kIsWeb) {
        web_download.downloadBytes(pdfBytes, filename, 'application/pdf');
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Invoice ${invoice.invoiceNumber}',
          subject: 'Invoice',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ready: $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice share failed: $e')),
      );
    }
  }

  Future<void> _printInvoice(BarInvoice invoice) async {
    try {
      final pdfBytes = await _buildInvoicePdf(invoice);
      final filename =
          PdfInvoiceGenerator.getInvoiceFilename(invoice.invoiceNumber);

      if (kIsWeb) {
        await web_download.printPdfBytes(pdfBytes, filename);
      } else {
        await Printing.layoutPdf(
          name: filename,
          onLayout: (_) async => pdfBytes,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice print dialog opened: $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice print failed: $e')),
      );
    }
  }

  List<ReceiptLineItem> _thermalInvoiceItems(BarInvoice invoice) {
    final provider = context.read<DrinkProvider>();
    return invoice.lines.map((line) {
      final drink = provider.getDrinkById(line.drinkId);
      return ReceiptLineItem(
        name: drink?.name ?? 'Unknown drink',
        quantity: line.quantityBottles.toDouble(),
        unitPrice: line.unitPrice,
        total: line.lineTotal(),
        unit: 'bottle',
      );
    }).toList();
  }

  Uint8List _buildThermalInvoiceSlip(BarInvoice invoice, int paperWidth) {
    final business = context.read<BusinessProvider>().currentBusiness;
    final auth = context.read<AuthProvider>();
    final notes = [
      if ((invoice.customerPhone ?? '').trim().isNotEmpty)
        'Phone: ${invoice.customerPhone!.trim()}',
      if ((invoice.tableLabel ?? '').trim().isNotEmpty)
        'Table/Tab: ${invoice.tableLabel!.trim()}',
      if ((invoice.notes ?? '').trim().isNotEmpty) invoice.notes!.trim(),
    ].join('\n');

    return EscPosReceiptGenerator.generateReceipt(
      businessName: business?.name ?? 'Bar',
      receiptNumber: invoice.invoiceNumber,
      receiptDate: invoice.createdAt,
      items: _thermalInvoiceItems(invoice),
      subtotal: invoice.subtotal,
      tax: invoice.tax,
      discount: invoice.discount,
      total: invoice.total,
      paymentMethod: invoice.status == 'converted' ? 'Paid' : 'Pending',
      customerName: invoice.customerName,
      cashier: invoice.workerName ?? auth.currentUser?.fullName,
      storeAddress: business?.address,
      storeTelephone: business?.phone,
      notes: notes.trim().isEmpty ? 'Bar invoice slip' : notes,
      currencySymbol: 'NGN ',
      paperWidth: paperWidth,
    );
  }

  Future<bool> _connectBluetoothPrinter(ThermalPrintingService service) async {
    await service.initialize();
    final settings =
        context.read<ReceiptSettingsProvider>().receiptSettings;
    final defaultMac = settings?.defaultPrinterMac;
    final devices = await service.getAvailablePrinters();

    if (devices.isEmpty && (defaultMac == null || defaultMac.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No Bluetooth printer found. Pair a printer first.'),
          ),
        );
      }
      return false;
    }

    ThermalPrinterDevice? selected;
    if (defaultMac != null && defaultMac.isNotEmpty) {
      selected = devices.firstWhere(
        (device) => device.address == defaultMac,
        orElse: () => ThermalPrinterDevice(
          address: defaultMac,
          name: defaultMac,
          type: 'bluetooth',
        ),
      );
    } else if (devices.length == 1) {
      selected = devices.first;
    } else {
      final choice = await showDialog<String?>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Select Bluetooth Printer'),
          children: devices
              .map(
                (device) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, device.address),
                  child: Text(
                    device.name.isNotEmpty ? device.name : device.address,
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (choice == null) return false;
      selected = devices.firstWhere((device) => device.address == choice);
    }

    final connected = await service.connectToPrinter(selected);
    if (!connected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to printer.')),
      );
    }
    return connected;
  }

  Future<void> _printInvoiceBluetooth(BarInvoice invoice) async {
    if (kIsWeb) {
      await _printInvoice(invoice);
      return;
    }

    try {
      final permissionsOk =
          await ThermalPrintingService.ensureBluetoothPermissions();
      if (!permissionsOk) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth permission was denied.')),
        );
        return;
      }

      final settings =
          context.read<ReceiptSettingsProvider>().receiptSettings;
      final paperWidth = settings?.paperWidth ?? 58;
      final service = ThermalPrintingService();
      final connected = await _connectBluetoothPrinter(service);
      if (!connected) return;

      final status = await service.printerManager.checkPrinterStatus();
      if (status != PrinterStatus.connected) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer is not connected.')),
        );
        return;
      }

      final slipBytes = _buildThermalInvoiceSlip(invoice, paperWidth);
      final printed = await service.printRawBytes(slipBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed
                ? 'Bluetooth invoice slip printed.'
                : 'Bluetooth invoice print failed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth invoice print failed: $e')),
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
                CustomButton(
                  text: 'Preview / Share Invoice',
                  backgroundColor: Colors.blue.shade700,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _shareInvoice(invoice);
                  },
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'Print Invoice',
                  type: ButtonType.outlined,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _printInvoice(invoice);
                  },
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'Print Invoice (Bluetooth)',
                  type: ButtonType.outlined,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _printInvoiceBluetooth(invoice);
                  },
                ),
                const SizedBox(height: 8),
                if (invoice.status == 'open') ...[
                  CustomButton(
                    text: 'Edit Invoice',
                    type: ButtonType.outlined,
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _handleEditInvoice(invoice);
                    },
                  ),
                  const SizedBox(height: 8),
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
                if (invoice.status == 'cancelled') ...[
                  CustomButton(
                    text: 'Reopen Invoice',
                    backgroundColor: Colors.orange.shade700,
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _handleReopenInvoice(invoice);
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
    final colorScheme = Theme.of(context).colorScheme;
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
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filter == 'open'
                                    ? 'No open tabs or invoices'
                                    : 'No invoices in this view',
                                style: AppTextStyles.heading5.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Saved invoices stay here until payment happens, so workers can convert them to sales without re-entering the order.',
                                style: AppTextStyles.body2.copyWith(
                                  color: colorScheme.onSurfaceVariant,
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
                            color: colorScheme.surfaceContainerHighest,
                            surfaceTintColor: colorScheme.surfaceContainerHighest,
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
                                              color: colorScheme.onSurface,
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
                                        color: colorScheme.onSurfaceVariant,
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
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '₦${invoice.total.toStringAsFixed(2)}',
                                          style: AppTextStyles.subtitle1.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (invoice.status == 'open') ...[
                                      const SizedBox(height: 12),
                                      Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: CustomButton(
                                                  text: 'Edit',
                                                  type: ButtonType.outlined,
                                                  onPressed: () =>
                                                      _handleEditInvoice(
                                                          invoice),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: CustomButton(
                                                  text: 'Convert',
                                                  backgroundColor:
                                                      Colors.green.shade600,
                                                  onPressed: () =>
                                                      _handleConvertInvoice(
                                                          invoice),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          CustomButton(
                                            text: 'Cancel',
                                            type: ButtonType.outlined,
                                            backgroundColor:
                                                Colors.red.shade300,
                                            textColor: Colors.red.shade700,
                                            onPressed: () =>
                                                _handleCancelInvoice(invoice),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (invoice.status == 'cancelled') ...[
                                      const SizedBox(height: 12),
                                      CustomButton(
                                        text: 'Reopen',
                                        backgroundColor: Colors.orange.shade700,
                                        onPressed: () =>
                                            _handleReopenInvoice(invoice),
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
