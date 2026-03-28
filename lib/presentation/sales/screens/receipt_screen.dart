import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../providers/receipt_settings_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/email_service.dart';
import '../../../core/utils/receipt_utility.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/thermal_printing_service.dart';
import '../../../services/pdf_receipt_generator.dart';
import '../../../services/receipt_asset_service.dart';
import '../../../services/web_download.dart' as web_download;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class ReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> sale;
  final bool isSubscriptionReceipt; // Special styling for subscription receipts
  final bool isInvoice; // Invoice mode for large orders

  const ReceiptScreen({
    super.key,
    required this.sale,
    this.isSubscriptionReceipt = false,
    this.isInvoice = false,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSending = false;
  late Color headerColor;

  @override
  void initState() {
    super.initState();
    headerColor = const Color.fromARGB(255, 12, 62, 102);
    // Schedule settings load after first frame to avoid calling
    // provider methods that may call setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReceiptSettings();
    });
  }

  void _loadReceiptSettings() {
    final businessProvider = context.read<BusinessProvider>();
    if (businessProvider.currentBusiness != null) {
      final receiptProvider = context.read<ReceiptSettingsProvider>();
      receiptProvider
          .fetchReceiptSettings(businessProvider.currentBusiness!.id);
    }
  }

  /// Normalize items coming from Firestore or other sources into
  /// a List<Map<String, dynamic>> so callers don't fail on type casts.
  List<Map<String, dynamic>> _normalizeItems(dynamic raw) {
    if (raw == null) return [];
    // Already the correct typed list
    if (raw is List<Map<String, dynamic>>) return raw;
    // If it's a List<dynamic>, try to convert each element safely
    if (raw is List) {
      return raw.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        // Fallback: wrap primitive/unknown into a map
        return <String, dynamic>{'value': e};
      }).toList();
    }
    // Anything else, return empty list
    return [];
  }

  /// Normalize a sale map to ensure consistent keys used by receipt UI
  Map<String, dynamic> _normalizeSale(Map<String, dynamic>? rawSale) {
    final sale = <String, dynamic>{};
    if (rawSale != null) sale.addAll(rawSale);

    // Date/time: accept multiple timestamp shapes (date, createdAt, timestamp, numeric seconds/ms, Firestore map)
    DateTime dateTime;
    final dateRaw = sale['date'] ?? sale['createdAt'] ?? sale['timestamp'] ?? sale['created_at'];

    if (dateRaw is DateTime) {
      dateTime = dateRaw;
    } else if (dateRaw is Timestamp) {
      dateTime = dateRaw.toDate();
    } else if (dateRaw is Map && (dateRaw.containsKey('_seconds') || dateRaw.containsKey('seconds'))) {
      // Firestore Timestamp serialized as map on web: {'_seconds': 123, '_nanoseconds': 0}
      final seconds = (dateRaw['_seconds'] ?? dateRaw['seconds']) as num? ?? 0;
      final nanos = (dateRaw['_nanoseconds'] ?? dateRaw['nanoseconds']) as num? ?? 0;
      final millis = seconds.toInt() * 1000 + (nanos ~/ 1000000).toInt();
      dateTime = DateTime.fromMillisecondsSinceEpoch(millis);
    } else if (dateRaw is num) {
      // Handle numeric timestamps: determine if given in seconds or milliseconds
      final numVal = dateRaw.toDouble();
      final millis = (numVal.abs() > 1e12) ? numVal.toInt() : (numVal * 1000).toInt();
      dateTime = DateTime.fromMillisecondsSinceEpoch(millis);
    } else if (dateRaw is String) {
      // Try ISO parse, otherwise try numeric parsing (seconds or ms), then fallback to now
      dateTime = DateTime.tryParse(dateRaw) ??
          (int.tryParse(dateRaw) != null
              ? DateTime.fromMillisecondsSinceEpoch((int.parse(dateRaw) > 1e12) ? int.parse(dateRaw) : int.parse(dateRaw) * 1000)
              : DateTime.now());
    } else {
      dateTime = DateTime.now();
    }

    // Store canonical ISO date and a short time string
    sale['date'] = dateTime.toIso8601String();
    sale['time'] = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    // Human-friendly display date (Month day, Year)
    sale['displayDate'] = DateFormat('MMMM d, yyyy').format(dateTime);

    // Cashier: broaden fallbacks and normalize to a non-empty string.
    // Handle string values and nested user maps (e.g., {'name': 'Alice'} or {'displayName': 'Alice'}).
    final cashierCandidates = [
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
      sale['owner'],
      sale['ownerName'],
      sale['owner_name'],
      // Additional keys used in reports/provider and historic payloads
      sale['workerName'],
      sale['worker_name'],
      sale['soldBy'],
      sale['sold_by'],
      sale['soldByName'],
      sale['sold_by_name'],
      sale['soldById'],
      sale['cashierId'],
    ];

    String? cashierValue;

    String? _extractName(dynamic c) {
      if (c == null) return null;
      if (c is String) {
        final s = c.trim();
        return s.isNotEmpty ? s : null;
      }
      if (c is Map) {
        const keys = [
          'name',
          'fullName',
          'full_name',
          'displayName',
          'display_name',
          'username',
          'userName',
          'email',
          'firstName',
          'first_name',
          'lastName',
          'last_name',
        ];
        for (var k in keys) {
          final v = c[k];
          if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
        }
        // Some user objects may store name under nested 'profile' or similar.
        if (c.containsKey('profile') && c['profile'] is Map) {
          for (var k in ['name', 'displayName', 'fullName']) {
            final v = c['profile'][k];
            if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
          }
        }
      }
      return null;
    }

    for (var c in cashierCandidates) {
      final extracted = _extractName(c);
      if (extracted != null) {
        cashierValue = extracted;
        break;
      }
    }

    sale['cashier'] = cashierValue ?? 'N/A';

    // Normalize items and map common field names to expected ones
    final rawItems = sale['items'];
    final items = _normalizeItems(rawItems).map((item) {
      final name = item['name'] ?? item['productName'] ?? item['product'] ?? item['productName'] ?? 'Item';
      final quantity = (item['quantity'] ?? item['qty'] ?? 1);
      final price = (item['price'] ?? item['unitPrice'] ?? item['unit_price'] ?? item['unitPriceN'] ?? 0.0);
      final desc = item['description'] ?? item['productDescription'] ?? item['desc'];
      final qtyNum = (quantity is num) ? quantity.toInt() : int.tryParse(quantity.toString()) ?? 1;
      final priceNum = (price is num) ? (price).toDouble() : double.tryParse(price.toString()) ?? 0.0;
      final itemTotal = (item['total'] ?? qtyNum * priceNum);
      return <String, dynamic>{
        'name': name,
        'quantity': qtyNum,
        'price': priceNum,
        'description': desc,
        'total': (itemTotal is num) ? (itemTotal).toDouble() : double.tryParse(itemTotal.toString()) ?? (qtyNum * priceNum),
      };
    }).toList();

    sale['items'] = items;

    // Totals: subtotal, tax, discount, finalAmount
    final subtotal = (sale['subtotal'] ?? sale['subTotal'] ?? items.fold<double>(0.0, (p, e) => p + ((e['total'] ?? 0) as num).toDouble()));
    final tax = (sale['tax'] ?? sale['taxAmount'] ?? 0.0);
    final discount = (sale['discount'] ?? sale['discountAmount'] ?? 0.0);
    final finalAmount = (sale['finalAmount'] ?? sale['totalAmount'] ?? sale['total'] ?? sale['finalTotal'] ?? subtotal - discount + (tax ?? 0.0));

    sale['subtotal'] = (subtotal is num) ? (subtotal).toDouble() : double.tryParse(subtotal.toString()) ?? 0.0;
    sale['tax'] = (tax is num) ? (tax).toDouble() : double.tryParse(tax.toString()) ?? 0.0;
    sale['discount'] = (discount is num) ? (discount).toDouble() : double.tryParse(discount.toString()) ?? 0.0;
    sale['finalAmount'] = (finalAmount is num) ? (finalAmount).toDouble() : double.tryParse(finalAmount.toString()) ?? 0.0;

    return sale;
  }

  /// Generate formatted receipt text
  String _generateReceiptText() {
    final sale = _normalizeSale(widget.sale);
    final items = _normalizeItems(sale['items']);
    final business = context.read<BusinessProvider>().currentBusiness;
    final receiptSettings =
        context.read<ReceiptSettingsProvider>().receiptSettings;

    final buffer = StringBuffer();

    // Header
    if (business != null && receiptSettings != null) {
      buffer.writeln('${business.name}');
      if (receiptSettings.headerNote != null && receiptSettings.headerNote!.isNotEmpty) {
        buffer.writeln(receiptSettings.headerNote);
      }
      if (receiptSettings.address != null && receiptSettings.address!.isNotEmpty) {
        buffer.writeln(receiptSettings.address);
      }
      if (receiptSettings.phone != null && receiptSettings.phone!.isNotEmpty) {
        buffer.writeln('Tel: ${receiptSettings.phone}');
      }
      buffer.writeln('');
    }

    // Receipt type indicator
    if (widget.isInvoice) {
      buffer.writeln('INVOICE\n');
    } else if (widget.isSubscriptionReceipt) {
      buffer.writeln('SUBSCRIPTION RECEIPT\n');
    } else {
      buffer.writeln('RECEIPT\n');
    }

    // Receipt details
    if (receiptSettings?.showOrderId ?? true) {
      buffer.writeln('Order ID: ${sale['id'] ?? 'N/A'}');
    }
    if (receiptSettings?.showDate ?? true) {
      buffer.writeln('Date: ${sale['displayDate'] ?? (sale['date'] != null ? DateFormat('MMMM d, yyyy').format(parseTimestamp(sale['date'])) : DateFormat('MMMM d, yyyy').format(DateTime.now()))}');
    }
    if (receiptSettings?.showTime ?? true) {
      buffer.writeln('Time: ${sale['time'] ?? 'N/A'}');
    }
    if (receiptSettings?.showCashier ?? false) {
      buffer.writeln('Cashier: ${sale['cashier'] ?? 'N/A'}');
    }
    if (receiptSettings?.showTableNo ?? false) {
      buffer.writeln('Table: ${sale['tableNo'] ?? 'N/A'}');
    }
    if (receiptSettings?.showNumberOfPersons ?? false) {
      buffer.writeln('Persons: ${sale['numberOfPersons'] ?? 'N/A'}');
    }

    buffer.writeln('\n${'-' * 40}');

    // Items
    for (var item in items) {
      final qty = (item['quantity'] ?? 1).toInt();
      final price = (item['price'] ?? 0.0).toDouble();
      final itemTotal = qty * price;
      buffer.writeln('${item['name'] ?? 'Item'} x$qty');
      buffer.writeln('  ${price.toStringAsFixed(2)} x $qty = ${itemTotal.toStringAsFixed(2)}');
    }

    buffer.writeln('-' * 40);

    // Totals
    buffer.writeln('Subtotal: ₦${(sale['subtotal'] ?? 0).toStringAsFixed(2)}');
    if (sale['tax'] != null && sale['tax'] > 0) {
      buffer.writeln('Tax: ₦${sale['tax'].toStringAsFixed(2)}');
    }
    if (sale['discount'] != null && sale['discount'] > 0) {
      buffer.writeln('Discount: -₦${sale['discount'].toStringAsFixed(2)}');
    }
    final totalDisplay = (sale['finalAmount'] ?? sale['total'] ?? sale['totalAmount'] ?? 0).toDouble();
    buffer.writeln('\nTOTAL: ₦${totalDisplay.toStringAsFixed(2)}');

    if (receiptSettings?.showPaymentMethod ?? true) {
      buffer.writeln('Payment: ${sale['paymentMethod'] ?? 'Cash'}');

    // Include final amount explicitly if present
    if (sale['finalAmount'] != null) {
      buffer.writeln('Final: ₦${(sale['finalAmount'] as num).toDouble().toStringAsFixed(2)}');
    }
    }

    // Footer
    if (business != null && receiptSettings != null) {
      buffer.writeln('');
      buffer.writeln('${receiptSettings.footerMessage ?? 'Thank you!'}');
      if (receiptSettings.bankName != null && receiptSettings.bankName!.isNotEmpty) {
        buffer.writeln('${receiptSettings.bankName}');
        if (receiptSettings.bankAccountNo != null && receiptSettings.bankAccountNo!.isNotEmpty) {
          buffer.writeln(receiptSettings.bankAccountNo);
        }
      }
      if (receiptSettings.website != null && receiptSettings.website!.isNotEmpty) {
        buffer.writeln(receiptSettings.website);
      }
    }

    return buffer.toString();
  }

  Future<void> _shareReceipt() async {
    try {
      final receiptText = _generateReceiptText();
      final business = context.read<BusinessProvider>().currentBusiness;
      final fileName = ReceiptUtility.generateReceiptFileName(
        businessName: business?.name ?? 'Receipt',
        orderId: widget.sale['id']?.toString(),
      );

      final imageBytes = await ReceiptAssetService.generateReceiptImage(
        businessName: business?.name ?? 'Receipt',
        receiptText: receiptText,
        receiptNumber: widget.sale['id']?.toString(),
      );

      final success = await ReceiptUtility.shareReceiptAsImage(
        imageData: imageBytes,
        businessName: business?.name ?? 'Receipt',
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Receipt shared successfully'
                : 'Failed to share receipt'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing receipt: $e')),
        );
      }
    }
  }

  Future<void> _downloadReceipt() async {
    try {
      final receiptText = _generateReceiptText();
      final business = context.read<BusinessProvider>().currentBusiness;
      final fileName = ReceiptUtility.generateReceiptFileName(
        businessName: business?.name ?? 'Receipt',
        orderId: widget.sale['id']?.toString(),
      );

      final imageBytes = await ReceiptAssetService.generateReceiptImage(
        businessName: business?.name ?? 'Receipt',
        receiptText: receiptText,
        receiptNumber: widget.sale['id']?.toString(),
      );

      final success = await ReceiptUtility.downloadReceiptAsImage(
        imageData: imageBytes,
        fileName: fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Receipt saved to downloads'
                : 'Failed to save receipt'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving receipt: $e')),
        );
      }
    }
  }

  Future<void> _sendReceiptEmail() async {
    final user = context.read<AuthProvider>().currentUser;
    final business = context.read<BusinessProvider>().currentBusiness;

    if (user?.email == null || business == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User or business not found')),
      );
      return;
    }

    setState(() => _isSending = true);

    final receiptText = _generateReceiptText();

    // Try to include structured items when available to avoid 'Item' placeholders
    final sale = _normalizeSale(widget.sale);
    final items = _normalizeItems(sale['items']);
    final formattedItems = items
        .map((item) => {
              'name': item['name'] ?? item['productName'] ?? 'Item',
              'quantity': item['quantity'] ?? item['qty'] ?? 1,
              'price': (item['price'] ?? item['unitPrice'] ?? 0).toDouble(),
            })
        .toList();

    final success = await context.read<EmailService>().sendReceiptEmail(
          recipient: user!.email,
          businessName: business.name,
          receiptText: receiptText,
          orderId: widget.sale['id'],
          items: formattedItems,
          subtotal: (sale['subtotal'] ?? 0.0).toDouble(),
          tax: (sale['tax'] ?? 0.0).toDouble(),
          total: (sale['total'] ?? 0.0).toDouble(),
          paymentMethod: sale['paymentMethod'] ?? 'Cash',
        );

    setState(() => _isSending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Receipt sent to email' : 'Failed to send email'),
        ),
      );
    }
  }

  Future<void> _printReceipt() async {
    try {
      final business = context.read<BusinessProvider>().currentBusiness;
      final receiptSettings =
          context.read<ReceiptSettingsProvider>().receiptSettings;

      if (business == null || receiptSettings == null) {
        throw Exception('Business or receipt settings not found');
      }

      // Generate 58mm formatted receipt
      final receiptText = _generateReceiptText();

      // Show print preview dialog
      if (mounted) {
        _showPrintPreviewDialog(receiptText);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Print error: $e');
    }
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
                color: headerColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
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
                      onPressed: () async {
                        Navigator.pop(context);
                        await _printToUsb(receiptText);
                      },
                      icon: const Icon(Icons.usb),
                      label: const Text('Print (USB)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('Send to Printer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerColor,
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
      
      var selectedPrinterMac = Provider.of<SettingsProvider>(context, listen: false).selectedPrinterMac ?? '';

      // If user hasn't selected a printer, fall back to business receipt settings
      if (selectedPrinterMac.isEmpty) {
        final receiptSettings = Provider.of<ReceiptSettingsProvider>(context, listen: false).receiptSettings;
        if (receiptSettings != null && (receiptSettings as dynamic).defaultPrinterMac != null) {
          selectedPrinterMac = (receiptSettings as dynamic).defaultPrinterMac as String? ?? '';
          debugPrint('[ReceiptScreen] Using receipt settings defaultPrinterMac: $selectedPrinterMac');
        }

        // Another fallback: business-level settings map
        if (selectedPrinterMac.isEmpty) {
          final business = context.read<BusinessProvider>().currentBusiness;
          try {
            if (business?.settings is Map) {
              final receiptMap = business!.settings!['receipt'];
              if (receiptMap is Map && receiptMap['defaultPrinterMac'] != null) {
                selectedPrinterMac = receiptMap['defaultPrinterMac'].toString();
                debugPrint('[ReceiptScreen] Using business.settings receipt.defaultPrinterMac: $selectedPrinterMac');
              }
            }
          } catch (e) {
            debugPrint('[ReceiptScreen] Error reading business-level printer setting: $e');
          }
        }
      }

      if (selectedPrinterMac.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No printer configured. Go to Settings → Printers to select a printer.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // If running on web, generate a PDF and trigger download / browser print flow
      if (kIsWeb) {
        try {
          final sale = _normalizeSale(widget.sale);
          final items = _normalizeItems(sale['items']);
          final receiptSettings = context.read<ReceiptSettingsProvider>().receiptSettings;
          final business = context.read<BusinessProvider>().currentBusiness;

          final formattedItems = items
              .map((item) => {
                    'name': item['name'] ?? 'Item',
                    'quantity': item['quantity'] ?? 1,
                    'price': item['price'] ?? 0.0,
                  })
              .toList();

          final cashierName = sale['workerName'] ?? sale['cashier'] ?? 'Staff';
          final footerWithPowered = (receiptSettings?.footerMessage?.isNotEmpty == true) ? '${receiptSettings!.footerMessage}\nPowered by Manage Care' : 'Powered by Manage Care';

          final pdfBytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
            businessName: business?.name ?? 'Business',
            receiptNumber: sale['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            receiptDate: parseTimestamp(sale['date']),
            items: formattedItems,
            subtotal: (sale['subtotal'] ?? 0.0).toDouble(),
            tax: (sale['tax'] ?? 0.0).toDouble(),
            total: (sale['total'] ?? 0.0).toDouble(),
            paymentMethod: sale['paymentMethod'] ?? 'Cash',
            paymentBreakdown: (sale['paymentBreakdown'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList(),
            customerName: (sale['customer'] is Map) ? (sale['customer']['name'] ?? sale['customer']['fullName'] ?? 'Customer') : (sale['customerName'] ?? 'Customer'),
            customerEmail: (sale['customer'] is Map) ? (sale['customer']['email'] ?? '') : (sale['customerEmail'] ?? ''),
            customHeader: receiptSettings?.headerNote,
            customFooter: footerWithPowered,
            paperWidth: (receiptSettings?.paperWidth ?? 58).toString(),
            cashier: cashierName,
            poweredByText: footerWithPowered,
            showQrCode: receiptSettings?.showQrCode ?? false,
            receiptUrlBase: receiptSettings?.receiptUrlBase,
          );

          final filename = PdfReceiptGenerator.getReceiptFilename(sale['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString());

          // Trigger browser download of the PDF (user can open and print with browser tools)
          web_download.downloadBytes(pdfBytes, filename, 'application/pdf');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF downloaded — open it in your browser to print'),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating PDF for web: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          debugPrint('Web print error: $e');
          return;
        }
      }

      // For Android: Use thermal printing service
      try {
        final paperWidth = Provider.of<ReceiptSettingsProvider>(context, listen: false).receiptSettings?.paperWidth ?? 58;
        
        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sending to thermal printer...'),
              duration: Duration(seconds: 10),
            ),
          );
        }
        
        final success = await ThermalPrintingService.printViaBluetooth(
          thermalText: receiptText,
          printerMac: selectedPrinterMac,
          paperWidth: paperWidth,
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Receipt sent to printer successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to send receipt to printer. Check settings.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Printer error: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        debugPrint('Thermal print error: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Print error: $e');
    }
  }

  /// Send receipt to a USB printer on Web using WebUSB
  Future<void> _printToUsb(String receiptText) async {
    try {
      if (!mounted) return;
      
      // This method is for USB printers on web which requires WebUSB API
      // For now, redirect to system print dialog
      if (kIsWeb) {
        await ThermalPrintingService.printViaBluetooth(
          thermalText: receiptText,
          printerMac: null, // null will use web system print
          paperWidth: 58,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opened system print dialog'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('USB printer support is for web only'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _shareReceiptAsImage() async {
    if (!ReceiptUtility.canCaptureReceiptImage()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Image capture not supported')));
      return;
    }

    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not capture receipt')));
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      // explicit gc
      image.dispose();
      if (pngBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to capture image')));
        return;
      }

      final business = context.read<BusinessProvider>().currentBusiness;
      final sale = widget.sale;
      final success = await ReceiptUtility.shareReceiptAsImage(
        imageData: pngBytes,
        businessName: business?.name ?? 'Receipt',
        fileName: ReceiptUtility.generateReceiptFileName(
          businessName: business?.name ?? 'Receipt',
          orderId: sale['id']?.toString(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Receipt image shared' : 'Failed to share image')),
        );
      }
    } catch (e) {
      debugPrint('Image share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportReceiptAsPdf() async {
    try {
      final business = context.read<BusinessProvider>().currentBusiness;
      final sale = widget.sale;
      final receiptSettings = context.read<ReceiptSettingsProvider>().receiptSettings;
      final items = _normalizeItems(sale['items']);

      final formattedItems = items
          .map((item) => {
                'name': item['name'] ?? 'Item',
                'quantity': item['quantity'] ?? 1,
                'price': item['price'] ?? 0.0,
              })
          .toList();

      final cashierName = sale['workerName'] ?? sale['cashier'] ?? 'Staff';
      final footerWithPowered = (receiptSettings?.footerMessage?.isNotEmpty == true)
          ? '${receiptSettings!.footerMessage}\nPowered by Manage Care'
          : 'Powered by Manage Care';

      final pdfBytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
        businessName: business?.name ?? 'Business',
        receiptNumber: sale['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        receiptDate: parseTimestamp(sale['date']),
        items: formattedItems,
        subtotal: (sale['subtotal'] ?? 0.0).toDouble(),
        tax: (sale['tax'] ?? 0.0).toDouble(),
        total: (sale['total'] ?? 0.0).toDouble(),
        paymentMethod: sale['paymentMethod'] ?? 'Cash',
        paymentBreakdown: (sale['paymentBreakdown'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList(),
        customerName: (sale['customer'] is Map)
            ? (sale['customer']['name'] ?? sale['customer']['fullName'] ?? 'Customer')
            : (sale['customerName'] ?? 'Customer'),
        customerEmail: (sale['customer'] is Map)
            ? (sale['customer']['email'] ?? '')
            : (sale['customerEmail'] ?? ''),
        customHeader: receiptSettings?.headerNote,
        customFooter: footerWithPowered,
        paperWidth: (receiptSettings?.paperWidth ?? 58).toString(),
        cashier: cashierName,
        poweredByText: footerWithPowered,
        showQrCode: receiptSettings?.showQrCode ?? false,
        receiptUrlBase: receiptSettings?.receiptUrlBase,
      );

      final fileName = ReceiptUtility.generateReceiptFileName(
        businessName: business?.name ?? 'Receipt',
        orderId: sale['id']?.toString(),
      );

      final saved = kIsWeb
          ? false
          : await ReceiptUtility.downloadReceiptAsPDF(
              pdfData: pdfBytes,
              fileName: fileName,
            );
      final shared = await ReceiptUtility.shareReceiptAsPDF(
        pdfData: pdfBytes,
        businessName: business?.name ?? 'Business',
        fileName: fileName,
      );

      if (mounted) {
        final message = saved && !kIsWeb
            ? (shared
                ? 'PDF saved and ready to share'
                : 'PDF saved to downloads')
            : (shared
                ? 'PDF shared successfully'
                : 'Failed to share PDF');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      debugPrint('PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting PDF: $e')));
      }
    }
  }

  /// Determine the appropriate number of decimal places for a quantity based on its unit
  int _getDecimalPlacesForUnit(String unit) {
    if (unit.isEmpty) return 0; // Default: no decimals for unspecified units
    
    final unitLower = unit.toLowerCase();
    
    // Volume/Fuel units: use 2 decimals
    if (['l', 'litre', 'liter', 'ltr', 'liters', 'litres', 'gallon', 'gal', 'ml', 'milliliter'].contains(unitLower)) {
      return 2;
    }
    
    // Cylinder/Gas tank units: use 2 decimals (can be fractional)
    if (['cyl', 'cylinder', 'cylinders', 'tank', 'tanks'].contains(unitLower)) {
      return 2;
    }
    
    // Weight units: use 2 decimals
    if (['kg', 'gram', 'g', 'lbs', 'lb', 'oz', 'ounce'].contains(unitLower)) {
      return 2;
    }
    
    // Count/Quantity units: use 0 decimals
    if (['unit', 'units', 'pcs', 'pieces', 'pc', 'piece', 'count', 'no', 'nos', 'items', 'item'].contains(unitLower)) {
      return 0;
    }
    
    // Default: 2 decimals for liquid/continuous measurements
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final sale = _normalizeSale(widget.sale);
    final items = _normalizeItems(sale['items']);
    final businessProvider = context.watch<BusinessProvider>();
    final business = businessProvider.currentBusiness;
    final receiptProvider = context.watch<ReceiptSettingsProvider>();
    final receiptSettings = receiptProvider.receiptSettings;

    // Determine header color based on receipt type
    Color headerColor = Colors.blue;
    if (widget.isSubscriptionReceipt &&
        receiptSettings?.highlightSubscriptionReceipts == true) {
      // Parse hex color from settings
      try {
        final hexColor = receiptSettings!.subscriptionHeaderColor;
        headerColor = Color(int.parse(hexColor.replaceFirst('#', '0xff')));
      } catch (_) {
        headerColor = const Color(0xFF9C27B0); // Purple for subscription
      }
    }

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        return !Navigator.canPop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(widget.isInvoice ? 'Invoice' : 'Receipt'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [headerColor, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: _shareReceiptAsImage,
              tooltip: 'Share as Image',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportReceiptAsPdf,
              tooltip: 'Export as PDF',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareReceipt,
              tooltip: 'Share',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadReceipt,
              tooltip: 'Download',
            ),
            if (receiptSettings?.enableEmailReceipts ?? true)
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CustomLoadingIndicator(),
                      )
                    : const Icon(Icons.email),
                onPressed: _isSending ? null : _sendReceiptEmail,
                tooltip: 'Email Receipt',
              ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'print',
                  child: Row(
                    children: [
                      Icon(Icons.print, size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 12),
                      const Text('Print'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'print') _printReceipt();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            children: [
              // Receipt Card - OPay Style Modern Design
              RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Modern Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              headerColor.withAlpha(0xF0),
                              AppColors.primaryDark.withAlpha(0xF0),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Business Logo/Avatar - Clean and Centered
                            if (business?.photoUrl != null &&
                                business!.photoUrl!.isNotEmpty)
                              ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: business.photoUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.white.withAlpha(20),
                                    child: const Icon(Icons.store, color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.store, color: Colors.white),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.store,
                                    size: 32, color: Colors.white.withAlpha(200)),
                              ),
                            const SizedBox(height: 16),
                            
                            // Business Name - Modern Typography
                            Text(
                              business?.name ?? 'My Business',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // Receipt Type Badge
                            if (widget.isSubscriptionReceipt)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(50),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'SUBSCRIPTION',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            else if (widget.isInvoice)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(50),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'INVOICE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Receipt Content - Clean Spacing
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Status Badge
                            if (!widget.isSubscriptionReceipt)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withAlpha(30),
                                  ),
                                ),
                                child: Text(
                                  (sale['status']?.toString().toUpperCase() ??
                                      'PAID'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.green,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),

                            if (!widget.isSubscriptionReceipt)
                              const SizedBox(height: 20),

                            // Receipt Metadata - Modern Grid
                            _buildModernReceiptMetadata(
                                sale, receiptSettings),

                            const SizedBox(height: 24),

                            // Divider
                            _buildDashedDivider(),

                            const SizedBox(height: 20),

                            // Items List - Clean Design
                            _buildModernItemsList(items),

                            const SizedBox(height: 20),

                            // Divider
                            Container(
                              height: 1,
                              color: Colors.grey.withAlpha(30),
                            ),

                            const SizedBox(height: 20),

                            // Totals Section - Emphasized
                            _buildModernTotalsSection(
                                sale, widget.isSubscriptionReceipt),

                            const SizedBox(height: 24),

                            // Payment Method
                            _buildModernPaymentSection(sale),

                            if (widget.isSubscriptionReceipt) ...[
                              const SizedBox(height: 24),
                              _buildSubscriptionInfo(sale),
                            ],

                            const SizedBox(height: 24),

                            // Footer - Professional
                            _buildModernFooter(business, receiptSettings),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Printer Options Below Receipt
              const SizedBox(height: 24),
              _buildPrinterOptionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfo(Map<String, dynamic> sale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_membership, color: Colors.purple[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Subscription Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.purple[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Plan:', sale['plan'] ?? 'Monthly'),
          const SizedBox(height: 8),
          _buildInfoRow('Billing Cycle:', sale['billingCycle'] ?? 'Monthly'),
          const SizedBox(height: 8),
          if (sale['nextBillingDate'] != null)
            _buildInfoRow('Next Billing:', sale['nextBillingDate']),
          const SizedBox(height: 8),
          if (sale['autoRenew'] != null)
            _buildInfoRow(
                'Auto Renewal:', sale['autoRenew'] ? 'Enabled' : 'Disabled'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String? method) {
    switch (method?.toLowerCase()) {
      case 'card':
      case 'credit card':
        return Icons.credit_card;
      case 'cash':
        return Icons.money;
      case 'mobile':
      case 'mpesa':
        return Icons.mobile_friendly;
      case 'bank':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey[300]),
              ),
            );
          }),
        );
      },
    );
  }

  // Modern OPay-style builder methods

  /// Build modern receipt metadata in grid layout
  Widget _buildModernReceiptMetadata(
      Map<String, dynamic> sale, dynamic settings) {
    final List<({String label, String value, IconData icon})> items = [];

    if (settings?.showOrderId ?? true) {
      items.add((
        label: 'Order ID',
        value: sale['id'] ?? 'N/A',
        icon: Icons.tag,
      ));
    }

    if (settings?.showDate ?? true) {
      items.add((
        label: 'Date',
        value: sale['displayDate'] ?? (sale['date'] != null ? DateFormat('MMMM d, yyyy').format(parseTimestamp(sale['date'])) : 'N/A'),
        icon: Icons.calendar_today,
      ));
    }

    if (settings?.showTime ?? true) {
      items.add((
        label: 'Time',
        value: sale['time'] ?? 'N/A',
        icon: Icons.access_time,
      ));
    }

    if (settings?.showCashier ?? false) {
      items.add((
        label: 'Cashier',
        value: sale['cashier'] ?? 'N/A',
        icon: Icons.person_outline,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build modern items list with clean typography
  Widget _buildModernItemsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No items in receipt',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'ITEM',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  'QTY',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'PRICE',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Items
        ...items.map((item) {
          final qty = (item['quantity'] ?? 1).toInt();
          final price = (item['price'] ?? 0.0).toDouble();
          final itemTotal = qty * price;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Product',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item['description'] != null &&
                          (item['description'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item['description'],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    qty.toStringAsFixed(_getDecimalPlacesForUnit(item['unit'] ?? item['uom'] ?? '')),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '₦${price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '₦${itemTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  /// Build modern totals section with visual hierarchy
  Widget _buildModernTotalsSection(
      Map<String, dynamic> sale, bool isSubscription) {
    final subtotal = (sale['subtotal'] ?? 0.0).toDouble();
    final tax = (sale['tax'] ?? 0.0).toDouble();
    final discount = (sale['discount'] ?? 0.0).toDouble();
    final total =
        (sale['total'] ?? sale['finalAmount'] ?? sale['totalAmount'] ?? 0.0)
            .toDouble();

    return Column(
      children: [
        if (subtotal > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₦${subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (tax > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tax',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₦${tax.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (discount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '-₦${discount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // Total - Emphasized
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: headerColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: headerColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: headerColor,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '₦${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: headerColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build modern payment section
  Widget _buildModernPaymentSection(Map<String, dynamic> sale) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withAlpha(25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getPaymentIcon(sale['paymentMethod']),
            size: 20,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  sale['paymentMethod'] ?? 'Cash',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build modern footer with professional appearance
  Widget _buildModernFooter(dynamic business, dynamic settings) {
    return Column(
      children: [
        Center(
          child: Column(
            children: [
              Text(
                settings?.footerMessage ?? 'Thank you for your business!',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: headerColor,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your trusted partner',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 0.1,
                ),
              ),
              if (settings?.phone != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Tel: ${settings.phone}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (settings?.website != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${settings.website}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build printer options section
  Widget _buildPrinterOptionsSection() {
    return Column(
      children: [
        Text(
          'Print Options',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPrinterOptionButton(
                icon: Icons.print,
                label: '58mm Printer',
                onPressed: _printReceipt,
                tooltip: 'Print to 58mm Bluetooth thermal printer',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPrinterOptionButton(
                icon: Icons.email,
                label: 'Email',
                onPressed: _isSending ? null : _sendReceiptEmail,
                tooltip: 'Send receipt to email',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPrinterOptionButton(
                icon: Icons.share,
                label: 'Share',
                onPressed: _shareReceipt,
                tooltip: 'Share receipt',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Build individual printer option button
  Widget _buildPrinterOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: onPressed == null
                  ? Colors.grey.withAlpha(30)
                  : Colors.grey.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: onPressed == null
                    ? Colors.grey.withAlpha(50)
                    : headerColor.withAlpha(40),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: onPressed == null ? Colors.grey : headerColor,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onPressed == null ? Colors.grey : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
