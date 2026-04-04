import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/datetime_utils.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/retail_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../services/thermal_printing_service.dart';
import '../../../services/email_receipt_service.dart';
import '../../../core/utils/receipt_utility.dart';
import '../../../services/pdf_receipt_generator.dart';
import '../../../services/receipt_asset_service.dart';
import '../../../providers/settings_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ReceiptDetailScreen extends StatefulWidget {
  final Map<String, dynamic> saleData;

  const ReceiptDetailScreen({
    required this.saleData,
    super.key,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  bool _isGeneratingPDF = false;
  bool _isSharingImage = false;
  final GlobalKey _receiptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final retailProvider = Provider.of<RetailProvider>(context, listen: false);
        retailProvider.loadProducts();
      } catch (_) {
        // ignore errors while loading products
      }
    });
  }

  String? _resolveCashier(Map<String, dynamic> sale) {
    // Similar strategy used elsewhere: try string keys then nested maps
    final candidates = [
      sale['cashier'],
      sale['cashierName'],
      sale['cashier_name'],
      sale['createdByName'],
      sale['created_by_name'],
      sale['createdBy'],
      sale['created_by'],
      sale['servedBy'],
      sale['served_by'],
      sale['attendant'],
      sale['operator'],
      sale['userName'],
      sale['user'],
      sale['employeeName'],
      sale['workerName'],
      sale['soldBy'],
      sale['ownerName'],
    ];

    String? extract(dynamic c) {
      if (c == null) return null;
      if (c is String) {
        final s = c.trim();
        return s.isEmpty ? null : s;
      }
      if (c is Map) {
        for (var k in ['name', 'displayName', 'fullName', 'username', 'email']) {
          final v = c[k];
          if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
        }
        if (c.containsKey('profile') && c['profile'] is Map) {
          for (var k in ['name', 'displayName']) {
            final v = c['profile'][k];
            if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
          }
        }
        // Handle DocumentReference-like maps (e.g., {'id': 'user_123'})
        if (c.containsKey('id') && c['id'] != null) {
          final v = c['id'].toString().trim();
          if (v.isNotEmpty) return v;
        }
      }
      return null;
    }

    for (var c in candidates) {
      final e = extract(c);
      if (e != null) return e;
    }
    return null;
  }

  Future<String?> _promptForEmail(BuildContext ctx, {String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String?>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Send Receipt'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Recipient email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Send')),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<void> _sendReceiptEmail() async {
    setState(() => _isGeneratingPDF = true);

    try {
      final file = await _createPdfFile();
      if (file == null) throw Exception('Failed to create PDF');

      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      final orderId = widget.saleData['id']?.toString() ?? '';
      final total = _numToDouble(widget.saleData['total']);
      final customerEmail = widget.saleData['customerEmail'] ?? widget.saleData['customer_email'] ?? widget.saleData['email'];
      final customerName = widget.saleData['customerName'] ?? widget.saleData['customer'] ?? widget.saleData['customer_name'] ?? '';

      String? recipient = customerEmail?.toString();
      if (recipient == null || recipient.isEmpty) {
        recipient = await _promptForEmail(context, initial: null);
      }

      if (recipient == null || recipient.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No recipient specified')));
        return;
      }

      final emailService = EmailReceiptService();
      final success = await emailService.sendReceiptEmail(
        recipientEmail: recipient,
        receiptNumber: orderId,
        businessName: business?.name ?? 'Business',
        pdfFile: file,
        totalAmount: total,
        customerName: customerName ?? '',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt sent successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send receipt')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending receipt: $e')));
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  Future<File?> _createPdfFile() async {
    try {
      final business = Provider.of<BusinessProvider>(
        context,
        listen: false,
      ).currentBusiness;
      final items = (widget.saleData['items'] as List<dynamic>? ?? [])
          .map((rawItem) {
            if (rawItem is Map<String, dynamic>) return rawItem;
            if (rawItem is Map) return Map<String, dynamic>.from(rawItem);
            return <String, dynamic>{'name': rawItem.toString()};
          })
          .toList();
      final orderId =
          widget.saleData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      final total = _numToDouble(
        widget.saleData['total'] ??
            widget.saleData['finalAmount'] ??
            widget.saleData['totalAmount'] ??
            widget.saleData['amount'] ??
            widget.saleData['saleAmount'] ??
            0.0,
      );
      final subtotal = _numToDouble(widget.saleData['subtotal'] ?? total);
      final tax = _numToDouble(widget.saleData['tax'] ?? 0.0);
      final discount = _numToDouble(widget.saleData['discount'] ?? 0.0);
      final paymentMethod =
          (widget.saleData['paymentMethod'] ?? 'Cash').toString();
      final customerName = (widget.saleData['customerName'] ??
              widget.saleData['customer'] ??
              widget.saleData['customer_name'] ??
              'Customer')
          .toString();
      final customerEmail = (widget.saleData['customerEmail'] ??
              widget.saleData['customer_email'] ??
              widget.saleData['email'])
          ?.toString();
      final bytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
        businessName: business?.name ?? 'Receipt',
        receiptNumber: orderId,
        receiptDate: parseTimestamp(
          widget.saleData['timestamp'] ??
              widget.saleData['createdAt'] ??
              widget.saleData['date'] ??
              widget.saleData['created_at'],
        ),
        items: items,
        subtotal: subtotal,
        tax: tax,
        total: total,
        paymentMethod: paymentMethod,
        paymentBreakdown: (widget.saleData['paymentBreakdown'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList(),
        customerName: customerName,
        customerEmail: customerEmail,
        customHeader: null,
        customFooter: null,
        paperWidth: '80',
        cashier: _resolveCashier(widget.saleData),
        discount: discount,
        businessLogoUrl: business?.logoUrl,
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );

      final directory = await getTemporaryDirectory();
      final fileName = 'Receipt_${widget.saleData['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file;

      /* Legacy fallback retained during migration.
      final pdf = pw.Document();
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;

      // Parse sale data
      final items = (widget.saleData['items'] as List<dynamic>?) ?? [];
      final orderId = widget.saleData['id'] ?? 'N/A';
      // Fallbacks for total using common keys
      final total = _numToDouble(widget.saleData['total'] ?? widget.saleData['finalAmount'] ?? widget.saleData['totalAmount'] ?? widget.saleData['amount'] ?? widget.saleData['saleAmount'] ?? 0.0);
      final timestamp = widget.saleData['timestamp'] ?? widget.saleData['createdAt'] ?? widget.saleData['date'] ?? widget.saleData['created_at'] ?? '';
      final paymentMethod = widget.saleData['paymentMethod'] ?? 'Cash';
      final cashier = _resolveCashier(widget.saleData);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context pdfContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    business?.name ?? 'Receipt',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),

                // Receipt Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Order ID: $orderId', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Date: ${_formatTimestamp(timestamp)}', style: const pw.TextStyle(fontSize: 12)),
                        if (cashier != null) pw.Text('Cashier: $cashier', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Payment: $paymentMethod', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Status: Completed', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Payment breakdown (show split payments if present)
                if (widget.saleData['paymentBreakdown'] != null && (widget.saleData['paymentBreakdown'] as List).isNotEmpty)
                  pw.Column(
                    children: (widget.saleData['paymentBreakdown'] as List).map((pb) {
                      final method = (pb['method'] ?? '').toString().toUpperCase();
                      final tx = pb['transactionId'] ?? '';
                      final amt = double.tryParse((pb['amount'] ?? 0.0).toString()) ?? 0.0;
                      final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
                      return pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('$method${tx != null && tx.toString().isNotEmpty ? ' • ${tx.toString()}' : ''}', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text(currencyFormat.format(amt), style: const pw.TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
                  )
                else
                  pw.SizedBox(height: 20),

                // Items Table
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFECF0F1)),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Items
                    for (var rawItem in items)
                      () {
                        Map<String, dynamic>? item;
                        if (rawItem is Map<String, dynamic>) item = rawItem;
                        else if (rawItem is String) {
                          try {
                            final parsed = json.decode(rawItem);
                            if (parsed is Map<String, dynamic>) item = parsed;
                          } catch (_) {}
                        }

                        if (item != null) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(_resolveProductName(context, item), style: const pw.TextStyle(fontSize: 11)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('${_resolveItemQuantity(item)}', style: const pw.TextStyle(fontSize: 11)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('₦${_resolveItemPrice(item).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text('₦${(_resolveItemPrice(item) * _resolveItemQuantity(item)).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 11)),
                              ),
                            ],
                          );
                        }

                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(rawItem?.toString() ?? 'Unknown Item', style: const pw.TextStyle(fontSize: 11)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('1', style: const pw.TextStyle(fontSize: 11)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('₦0.00', style: const pw.TextStyle(fontSize: 11)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('₦0.00', style: const pw.TextStyle(fontSize: 11)),
                            ),
                          ],
                        );
                      }(),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Total
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Total: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('₦${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 40),

                // Footer
                pw.Center(
                  child: pw.Text('Thank you for your purchase!', style: const pw.TextStyle(fontSize: 12)),
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final fileName = 'Receipt_${widget.saleData['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file;
      */
    } catch (e) {
      debugPrint('PDF create error: $e');
      return null;
    }
  }

  Future<void> _generateAndSharePDF() async {
    setState(() => _isGeneratingPDF = true);

    try {
      final file = await _createPdfFile();
      if (file == null) throw Exception('Failed to create PDF');

      final bytes = await file.readAsBytes();
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      final filename = ReceiptUtility.generateReceiptFileName(
        businessName: business?.name ?? 'Receipt',
        orderId: widget.saleData['id']?.toString(),
      );

      final saved = kIsWeb
          ? false
          : await ReceiptUtility.downloadReceiptAsPDF(
              pdfData: bytes,
              fileName: filename,
            );
      final shared = await ReceiptUtility.shareReceiptAsPDF(
        pdfData: bytes,
        businessName: business?.name ?? 'Receipt',
        fileName: filename,
      );

      if (mounted) {
        final message = saved && shared
            ? 'PDF saved and shared'
            : saved
                ? 'PDF saved to downloads'
                : shared
                    ? 'PDF shared successfully'
                    : 'Failed to share receipt PDF';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  Future<void> _shareAsImage() async {
    setState(() => _isSharingImage = true);
    try {
      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
      final bytes = await ReceiptAssetService.generateReceiptImage(
        businessName: business?.name ?? 'Receipt',
        receiptText: _generate58mmReceiptText(),
        receiptNumber: widget.saleData['id']?.toString(),
        businessLogoUrl: business?.logoUrl,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );
      final filename = ReceiptUtility.generateReceiptFileName(
        businessName: business?.name ?? 'Receipt',
        orderId: widget.saleData['id']?.toString(),
      );

      final saved = kIsWeb
          ? false
          : await ReceiptUtility.downloadReceiptAsImage(
              imageData: bytes,
              fileName: filename,
            );
      final shared = await ReceiptUtility.shareReceiptAsImage(
        imageData: bytes,
        businessName: business?.name ?? 'Receipt',
        fileName: filename,
      );

      if (mounted) {
        final message = saved && shared
            ? 'Receipt image saved and shared'
            : saved
                ? 'Receipt image saved to downloads'
                : shared
                    ? 'Receipt image shared successfully'
                    : 'Failed to share receipt image';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      debugPrint('Share image error: $e');
    } finally {
      setState(() => _isSharingImage = false);
    }
  }

  DateTime _toDateTime(dynamic timestamp) {
    return parseTimestamp(timestamp);
  }

  String _formatTimestamp(dynamic timestamp) {
    final dt = _toDateTime(timestamp);
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  /// Generate formatted 58mm receipt text for printer preview
  String _generate58mmReceiptText() {
    final items = (widget.saleData['items'] as List<dynamic>?) ?? [];

    final formattedItems = items.map((item) => {
          'name': item['productName'] ?? item['name'] ?? 'Item',
          'quantity': item['quantity'] ?? 1,
          'price': (item['price'] ?? item['unitPrice'] ?? 0.0),
        }).toList();

    final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;
    final cashier = _resolveCashier(widget.saleData);

    return ThermalPrintingService.createCompleteReceipt(
      businessName: business?.name ?? 'My Business',
      paperWidth: 58,
      items: formattedItems.cast<Map<String, dynamic>>(),
      totalAmount: _numToDouble(
        widget.saleData['total'] ??
            widget.saleData['finalAmount'] ??
            widget.saleData['totalAmount'] ??
            widget.saleData['amount'] ??
            widget.saleData['saleAmount'],
      ),
      paymentMethod: widget.saleData['paymentMethod'] ?? 'Cash',
      orderId: widget.saleData['id'],
      cashier: cashier,
    );
  }

  /// Show print preview dialog with option to send to printer
  void _showPrintPreviewDialog(String receiptText) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 14, 39, 95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Print Preview (58mm)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Preview Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: 200, // 58mm width approximation
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    receiptText,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Send to Printer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _sendToPrinter(receiptText);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Send receipt to Bluetooth thermal printer
  Future<void> _sendToPrinter(String receiptText) async {
    try {
      if (!mounted) return;

      final selectedPrinterMac = Provider.of<SettingsProvider>(context, listen: false).selectedPrinterMac ?? '';

      if (selectedPrinterMac.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No printer configured. Go to Settings > Printers to select a printer.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sending to thermal printer...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Send to Bluetooth thermal printer
      final success = await ThermalPrintingService.printViaBluetooth(
        thermalText: receiptText,
        printerMac: selectedPrinterMac,
        paperWidth: 58,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Receipt printed successfully'
                  : 'Failed to print receipt',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Print error: $e');
    }
  }

  /// Send receipt to a USB printer on Web using the new thermal printing service
  Future<void> _printReceiptUsb(String receiptText) async {
    try {
      if (!mounted) return;

      try {
        // Use the thermal printing service
        final success = await ThermalPrintingService.printViaBluetooth(
          thermalText: receiptText,
            printerMac: null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Print dialog opened' : 'Failed to open print dialog'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

  String _resolveProductName(BuildContext context, dynamic raw) {
    Map<String, dynamic>? item;
    if (raw is Map<String, dynamic>) {
      item = raw;
    } else if (raw is String) {
      try {
        final parsed = json.decode(raw);
        if (parsed is Map<String, dynamic>) item = parsed;
      } catch (_) {
        // leave item null
      }
    }

    if (item != null) {
      final retailProvider = Provider.of<RetailProvider>(context, listen: false);

      // Prefer explicit name fields
      final cand1 = item['productName'];
      final cand2 = item['name'];
      if (cand1 != null && cand1.toString().isNotEmpty) return cand1.toString();
      if (cand2 != null && cand2.toString().isNotEmpty) return cand2.toString();

      // product field may be Map or stringified JSON
      final prod = item['product'];
      if (prod is Map && prod['name'] != null && prod['name'].toString().isNotEmpty) {
        return prod['name'].toString();
      }
      if (prod is String) {
        try {
          final parsed = json.decode(prod);
          if (parsed is Map && parsed['name'] != null && parsed['name'].toString().isNotEmpty) {
            return parsed['name'].toString();
          }
        } catch (_) {}
        if (prod.isNotEmpty) return prod;
      }

      if (item['productId'] != null) {
        final pid = item['productId'].toString();
        final p = retailProvider.products.firstWhere((prod) => prod.id == pid,
            orElse: () => Product(id: pid, name: 'Unknown Product', price: 0, stock: 0, category: 'Unknown'));
        return p.name;
      }
    }

    // Fallback to raw string representation
    if (raw != null) return raw.toString();
    return 'Unknown Product';
  }

  double _numToDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  double _resolveItemPrice(Map<String, dynamic> item) {
    final candidates = [
      item['price'],
      item['unitPrice'],
      item['unit_price'],
      item['sellingPrice'],
      item['salePrice'],
      item['amount'],
      item['linePrice'],
    ];
    for (var c in candidates) {
      final d = _numToDouble(c);
      if (d > 0) return d;
    }
    // product nested
    if (item['product'] is Map) {
      final p = item['product'];
      for (var k in ['price', 'unitPrice', 'salePrice']) {
        final d = _numToDouble(p[k]);
        if (d > 0) return d;
      }
    }
    return 0.0;
  }

  int _resolveItemQuantity(dynamic raw) {
    Map<String, dynamic>? item;
    if (raw is Map<String, dynamic>) {
      item = raw;
    } else if (raw is String) {
      try {
        final parsed = json.decode(raw);
        if (parsed is Map<String, dynamic>) item = parsed;
      } catch (_) {
        // not JSON
      }
    }

    if (item != null) {
      final q = item['quantity'] ?? item['qty'] ?? item['count'] ?? item['q'] ?? 1;
      if (q is num) return q.toInt();
      final parsed = int.tryParse(q?.toString() ?? '');
      return parsed ?? 1;
    }

    // fallback
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.saleData['items'] as List<dynamic>?) ?? [];
    final orderId = widget.saleData['id'] ?? 'N/A';
    final total = _numToDouble(widget.saleData['total'] ?? widget.saleData['finalAmount'] ?? widget.saleData['totalAmount'] ?? widget.saleData['amount'] ?? widget.saleData['saleAmount']);
    final timestamp = widget.saleData['timestamp'] ?? widget.saleData['createdAt'] ?? widget.saleData['date'] ?? widget.saleData['created_at'] ?? null;
    final paymentMethod = widget.saleData['paymentMethod'] ?? widget.saleData['payment_method'] ?? 'Cash';
    final business = Provider.of<BusinessProvider>(context).currentBusiness;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Receipt Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Receipt Card
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Modern OPay-style Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary.withOpacity(0.95), AppColors.primaryDark.withOpacity(0.95)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Business Logo or Placeholder
                        if (business?.logoUrl != null && business!.logoUrl!.isNotEmpty)
                          ClipOval(
                            child: Image.network(
                              business.logoUrl!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.store, color: Colors.white.withAlpha(200), size: 36),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          business?.name ?? 'My Business',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Receipt',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Metadata Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Order ID', style: AppTextStyles.body2Secondary),
                              const SizedBox(height: 4),
                              Text(orderId, style: AppTextStyles.heading5),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date', style: AppTextStyles.body2Secondary),
                              const SizedBox(height: 4),
                              Text(_formatTimestamp(timestamp), style: AppTextStyles.body1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Cashier row (customer field removed per request)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cashier', style: AppTextStyles.body2Secondary),
                              const SizedBox(height: 4),
                              Text(_resolveCashier(widget.saleData) ?? 'N/A', style: AppTextStyles.body1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Items List - Modern
                  const Text('Items', style: AppTextStyles.heading5),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      for (var rawItem in items)
                        () {
                          // parse if stringified JSON
                          Map<String, dynamic>? item;
                          if (rawItem is Map<String, dynamic>) item = rawItem;
                          else if (rawItem is String) {
                            try {
                              final parsed = json.decode(rawItem);
                              if (parsed is Map<String, dynamic>) item = parsed;
                            } catch (_) {
                              // not JSON
                            }
                          }

                          if (item != null) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _resolveProductName(context, item),
                                            style: AppTextStyles.subtitle1,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text('Qty: ${_resolveItemQuantity(item)}', style: AppTextStyles.body2Secondary),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₦${(_resolveItemPrice(item) * _resolveItemQuantity(item)).toStringAsFixed(2)}', style: AppTextStyles.heading5),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }

                          // fallback for strings or unexpected item shape
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(rawItem?.toString() ?? 'Unknown Item', style: AppTextStyles.body2),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₦0.00', style: AppTextStyles.heading5),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }(),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Payment & Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Method', style: AppTextStyles.body2Secondary),
                          const SizedBox(height: 4),
                          Text(paymentMethod, style: AppTextStyles.body1),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Completed', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: AppTextStyles.heading4),
                      Text('₦${total.toStringAsFixed(2)}', style: AppTextStyles.price),
                    ],
                  ),
                ],
              ),
            ),
            ),
            const SizedBox(height: 24),

            // Action Buttons - Download, Share, Print
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingPDF ? null : _generateAndSharePDF,
                        icon: const Icon(Icons.download),
                        label: Text(_isGeneratingPDF ? 'Generating PDF...' : 'Save / Share PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingPDF ? null : _sendReceiptEmail,
                        icon: const Icon(Icons.email),
                        label: Text(_isGeneratingPDF ? 'Sending...' : 'Send Email'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSharingImage ? null : _shareAsImage,
                        icon: const Icon(Icons.image),
                        label: Text(_isSharingImage ? 'Sharing...' : 'Share / Save Image'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final receiptText = _generate58mmReceiptText();
                          _showPrintPreviewDialog(receiptText);
                        },
                        icon: const Icon(Icons.remove_red_eye),
                        label: const Text('Preview (58mm)'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final receiptText = _generate58mmReceiptText();
                          await _printReceiptUsb(receiptText);
                        },
                        icon: const Icon(Icons.usb),
                        label: const Text('Print (USB)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final receiptText = _generate58mmReceiptText();
                          await _sendToPrinter(receiptText);
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Print (58mm)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }
}

