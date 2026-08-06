import 'dart:typed_data';

import 'package:business_manager/core/access_control.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/receipt_utility.dart';
import '../../../core/utils/decimal_input_formatter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../services/thermal_printer_manager.dart';
import '../../../services/thermal_printing_service.dart';
import '../../../services/esc_pos_receipt_generator.dart';
import '../../../services/pdf_receipt_generator.dart';
import '../../settings/screens/pdf_preview_page.dart';
import '../../../services/web_download.dart' as web_download;
import '../../../data/models/sale_model.dart';
import '../../../services/email_service.dart';
import '../../../services/analytics_service.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/receipt_settings_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/utils/worker_permissions.dart';
import '../../../core/utils/currency.dart';
import '../../../services/pdf_invoice_generator.dart';
import '../../../../providers/pharmacy_provider.dart';
import '../../../../services/prescription_print_service.dart';

/// Post-sale action sheet allowing users to choose:
/// Share receipt as text
/// Email receipt (Pro feature)
/// Print via Bluetooth thermal printer
class PostSaleActionSheet extends StatefulWidget {
  final String receiptText;
  final String businessName;
  final String? orderId;
  final String? customerEmail;
  final Map<String, dynamic> saleData;
  final Future<dynamic>? pdfFuture; // File on mobile, Uint8List bytes on web
  final bool allowEditing; // Whether to show price/discount editing functionality
  final bool invoiceLockedAfterCheckout; // When true, hide invoice generation buttons

  const PostSaleActionSheet({
    required this.receiptText,
    required this.businessName,
    required this.orderId,
    this.customerEmail,
    required this.saleData,
    this.pdfFuture,
    this.allowEditing = true, // Default to true for backward compatibility
    this.invoiceLockedAfterCheckout = false, // Default: allow invoice after checkout
    super.key,
  });

  @override
  State<PostSaleActionSheet> createState() => _PostSaleActionSheetState();
}

class _PostSaleActionSheetState extends State<PostSaleActionSheet> {
  bool _isSharing = false;
  bool _isEmailing = false;
  bool _isPrinting = false;
  bool _isPreviewing = false;

  String? _statusMessage;
  Color? _statusColor;

  // PDF generation state
  bool _pdfGenerating = false;
  Uint8List? _pdfBytes;
  File? _pdfFile;
  bool _lastGeneratedPdfWasInvoice = false;

  // Editable sale data
  late List<Map<String, dynamic>> _editableItems;
  late double _editableDiscount;
  late double _editableTax;

  // Invoice prompt state
  bool _invoiceDialogShown = false;
  bool _autoGeneratingInvoice = false;

  bool get _isCheckoutLockedToReceipt => widget.invoiceLockedAfterCheckout;
  bool get _isCompletedSaleReceiptFlow {
    final status = (widget.saleData['status'] ?? widget.saleData['saleStatus'] ?? widget.saleData['paymentStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return _isCheckoutLockedToReceipt ||
        const {'completed', 'complete', 'paid', 'settled', 'checked_out', 'checkout_complete', 'closed'}
            .contains(status);
  }

  // Resolve payment method from various possible sale map keys and normalize
  String _getPaymentMethod(Map<String, dynamic> data) {
    if (data.isEmpty) return 'Cash';
    final candidates = <dynamic>[
      data['paymentMethod'],
      data['payment_method'],
      data['payment'],
      data['method'],
      data['tender'],
      data['tenders'],
    ];

    for (final c in candidates) {
      if (c == null) continue;
      if (c is String && c.trim().isNotEmpty) return _normalizePayment(c);
      if (c is Map) {
        final v = c['method'] ?? c['name'] ?? c['payment'];
        if (v is String && v.trim().isNotEmpty) return _normalizePayment(v);
      }
      if (c is List && c.isNotEmpty) {
        final first = c.first;
        if (first is Map) {
          final v = first['method'] ?? first['name'] ?? first['payment'];
          if (v is String && v.trim().isNotEmpty) return _normalizePayment(v);
        } else if (first is String && first.trim().isNotEmpty) {
          return _normalizePayment(first);
        }
      }
    }

    // Fallback to paymentBreakdown if present
    final pb = data['paymentBreakdown'] ?? data['payment_breakdown'];
    if (pb is List && pb.isNotEmpty) {
      final first = pb.first;
      if (first is Map) {
        final v = first['method'] ?? first['name'] ?? first['payment'];
        if (v is String && v.trim().isNotEmpty) return _normalizePayment(v);
      }
    }

    return 'Cash';
  }

  List<Map<String, dynamic>>? _getPaymentBreakdown(Map<String, dynamic> data) {
    final raw = data['paymentBreakdown'] ?? data['payment_breakdown'] ?? data['tenders'] ?? data['tender'];
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return {'method': e.toString(), 'amount': null};
      }).toList();
    }
    if (raw is Map) return [Map<String, dynamic>.from(raw)];
    return [{'method': raw.toString(), 'amount': null}];
  }

  String _normalizePayment(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Cash';
    return s[0].toUpperCase() + (s.length > 1 ? s.substring(1).toLowerCase() : '');
  }

  String? _copyLabelForReceipt(int index, int totalCopies) {
    if (totalCopies < 2) {
      return null;
    }
    if (index == 0) {
      return 'CUSTOMER COPY';
    }
    if (index == 1) {
      return 'BUSINESS COPY';
    }
    return 'COPY ${index + 1}';
  }

  String _copyNameForDisplay(int index, int totalCopies) {
    final label = _copyLabelForReceipt(index, totalCopies);
    if (label == null) {
      return 'Receipt';
    }
    return toBeginningOfSentenceCase(label.toLowerCase()) ?? label;
  }

  Future<bool> _confirmPrintAdditionalCopy(String copyName) async {
    if (!mounted) {
      return false;
    }

    final normalizedName = copyName.toLowerCase();
    final content = normalizedName == 'business copy'
        ? 'Customer copy has been printed. Do you want to print the business copy now?'
        : 'The previous copy has been printed. Do you want to print the $normalizedName now?';

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Print $normalizedName?'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Print'),
          ),
        ],
      ),
    );

    return shouldPrint ?? false;
  }

  String? _extractItemUnit(Map<String, dynamic> item) {
    final rawUnit = (item['unit'] ??
            item['unitName'] ??
            item['uom'] ??
            item['saleUnit'] ??
            item['inventoryUnit'] ??
            item['resolvedSaleUnit'] ??
            item['selectedUnit'] ??
            ((item['product'] is Map)
                ? (item['product']['saleUnit'] ??
                    item['product']['unit'] ??
                    item['product']['unitName'] ??
                    item['product']['uom'])
                : null) ??
            '')
        .toString()
        .trim();
    return rawUnit.isEmpty ? null : rawUnit;
  }

  String? _extractPricingMode(Map<String, dynamic> item) {
    final raw = (item['pricingMode'] ?? item['priceType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return raw.isEmpty ? null : raw;
  }

  String _displaySaleItemName(Map<String, dynamic> item) {
    final baseName = (item['productName'] ??
            item['name'] ??
            ((item['product'] is Map) ? item['product']['name'] : null) ??
            'Item')
        .toString()
        .trim();
    var displayName = baseName.isEmpty ? 'Item' : baseName;

    final unit = _extractItemUnit(item);
    if (unit != null && unit.isNotEmpty) {
      final normalizedName = displayName.toLowerCase();
      final normalizedUnit = unit.toLowerCase();
      if (!normalizedName.contains('($normalizedUnit)') &&
          !normalizedName.endsWith(' $normalizedUnit')) {
        displayName = '$displayName ($unit)';
      }
    }

    final pricingMode = _extractPricingMode(item);
    if (pricingMode == 'retail' || pricingMode == 'wholesale') {
      final suffix = '[${pricingMode!.toUpperCase()}]';
      if (!displayName.toUpperCase().contains(suffix)) {
        displayName = '$displayName $suffix';
      }
    }

    return displayName;
  }

  String? _receiptStoreName() {
    final rawStoreName = (widget.saleData['storeName'] ??
            widget.saleData['store_name'] ??
            (widget.saleData['store'] is Map
                ? widget.saleData['store']['name']
                : null))
        ?.toString()
        .trim();
    if (rawStoreName == null || rawStoreName.isEmpty) {
      return null;
    }
    if (rawStoreName.toLowerCase() == widget.businessName.trim().toLowerCase()) {
      return null;
    }
    return rawStoreName;
  }

  bool get _hasPharmacyPrescription {
    final category =
        (widget.saleData['category'] ?? widget.saleData['type'] ?? '')
            .toString()
            .toLowerCase();
    return category.contains('pharmacy') &&
        ((widget.saleData['prescriptionId'] ?? '').toString().isNotEmpty);
  }

  Future<void> _printPharmacyPrescription() async {
    final provider = context.read<PharmacyProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;
    final prescriptionId =
        (widget.saleData['prescriptionId'] ?? '').toString().trim();
    if (prescriptionId.isEmpty) {
      setState(() {
        _statusMessage = 'No prescription was attached to this sale.';
        _statusColor = Colors.orange;
      });
      return;
    }

    final matches =
        provider.prescriptions.where((p) => p.id == prescriptionId).toList();
    if (matches.isEmpty) {
      setState(() {
        _statusMessage = 'Prescription data is not available yet.';
        _statusColor = Colors.orange;
      });
      return;
    }

    final prescription = matches.first;
    final patient = provider.getPatientById(prescription.patientId);
    final itemRows =
        (widget.saleData['prescriptionItems'] as List<dynamic>? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();

    await PrescriptionPrintService.printPrescription(
      context,
      businessName: business?.name ?? widget.businessName,
      prescription: prescription,
      patientName: prescription.patientName ??
          patient?.name ??
          (widget.saleData['prescriptionPatientName']?.toString() ??
              'Walk-in Patient'),
      itemRows: itemRows,
      patientAge: provider.calculateAge(
        patient?.dateOfBirth ?? prescription.patientDateOfBirth,
      ),
    );

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Prescription print dialog opened';
      _statusColor = Colors.green;
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[PostSaleActionSheet] Initialized with orderId: ${widget.orderId}');

    // Auto-generate the appropriate PDF after checkout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isCompletedSaleReceiptFlow) {
        _generatePdf();
      } else {
        _autoGenerateAndPromptInvoice();
      }
    });

    // Listen for background PDF generation if provided
    if (widget.pdfFuture != null && !_isCompletedSaleReceiptFlow) {
      setState(() => _pdfGenerating = true);
      widget.pdfFuture!.then((res) async {
        if (res == null) {
          setState(() {
            _pdfGenerating = false;
            _statusMessage = 'PDF generation failed';
            _statusColor = Colors.red;
          });
          return;
        }

        if (kIsWeb) {
          if (res is Uint8List) {
            setState(() {
              _pdfBytes = res;
              _pdfGenerating = false;
              _statusMessage = 'PDF ready (click Save/Share)';
              _statusColor = Colors.green;
            });
          } else {
            setState(() {
              _pdfGenerating = false;
              _statusMessage = 'PDF ready';
              _statusColor = Colors.green;
            });
          }
        } else {
          // IO platforms: generator returns a File
          if (res is File) {
            setState(() {
              _pdfFile = res;
              _pdfGenerating = false;
              _statusMessage = 'PDF generated';
              _statusColor = Colors.green;
            });
          } else if (res is Uint8List) {
            // fallback
            setState(() {
              _pdfBytes = res;
              _pdfGenerating = false;
              _statusMessage = 'PDF ready';
              _statusColor = Colors.green;
            });
          } else {
            setState(() {
              _pdfGenerating = false;
              _statusMessage = 'PDF generation finished';
              _statusColor = Colors.green;
            });
          }
        }
      }).catchError((e) {
        setState(() {
          _pdfGenerating = false;
          _statusMessage = 'Error generating PDF: $e';
          _statusColor = Colors.red;
        });
      });
    }

    // Initialize editable sale data
    _initializeEditableData();
  }

  void _initializeEditableData() {
    // Deep copy the items for editing and ensure 'total' field is set correctly
    _editableItems = List<Map<String, dynamic>>.from(
      (widget.saleData['items'] as List? ?? []).map((item) {
        final copiedItem = Map<String, dynamic>.from(item);
        final quantity = (copiedItem['quantity'] as num?)?.toDouble() ?? 1.0;
        final price = (copiedItem['price'] as num?)?.toDouble() ?? (copiedItem['unitPrice'] as num?)?.toDouble() ?? 0.0;
        // Ensure 'total' field is set correctly
        copiedItem['total'] = (copiedItem['total'] as num?)?.toDouble() ?? (price * quantity);
        return copiedItem;
      })
    );
    _editableDiscount = (widget.saleData['discount'] as num?)?.toDouble() ?? 0.0;
    _editableTax = (widget.saleData['tax'] as num?)?.toDouble() ?? 0.0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? 0.0;
    return 0.0;
  }

  double _saleItemQuantity(Map<String, dynamic> item) =>
      _toDouble(item['quantity'] ?? item['qty'] ?? 1);

  double _saleItemUnitPrice(Map<String, dynamic> item) =>
      _toDouble(item['unitPrice'] ?? item['price'] ?? item['sellingPrice']);

  double _saleItemTotal(Map<String, dynamic> item) {
    final explicitTotal = _toDouble(item['total'] ?? item['subtotal'] ?? item['lineTotal']);
    if (explicitTotal > 0) return explicitTotal;
    return _saleItemQuantity(item) * _saleItemUnitPrice(item);
  }

  List<Map<String, dynamic>> _invoiceCartItems() {
    return (widget.saleData['items'] as List? ?? []).map((item) {
      final map = item is Map<String, dynamic>
          ? Map<String, dynamic>.from(item)
          : item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{};
      final quantity = _saleItemQuantity(map);
      final unitPrice = _saleItemUnitPrice(map);
      final lineTotal = _saleItemTotal(map);
      final name = map['name'] ?? map['productName'] ?? map['menuItemName'] ?? 'Item';

      return {
        'productId': map['productId'] ?? map['id'] ?? '',
        'productName': name,
        'menuItemName': name,
        'name': name,
        'quantity': quantity,
        'price': unitPrice,
        'unitPrice': unitPrice,
        'subtotal': lineTotal,
        'total': lineTotal,
        'specialInstructions': map['specialInstructions'],
        'selectedOptions': map['selectedOptions'] ?? [],
      };
    }).toList();
  }

  double _invoiceSubtotal() {
    final explicitSubtotal = _toDouble(widget.saleData['subtotal']);
    if (explicitSubtotal > 0) return explicitSubtotal;
    return _invoiceCartItems().fold<double>(
      0.0,
      (sum, item) => sum + _toDouble(item['total']),
    );
  }

  double _invoiceTax() => _toDouble(widget.saleData['tax']);

  double _invoiceDiscount() => _toDouble(widget.saleData['discount']);

  double _invoiceTotal() {
    final explicitTotal =
        _toDouble(widget.saleData['total'] ?? widget.saleData['finalAmount']);
    if (explicitTotal > 0) return explicitTotal;
    final total = _invoiceSubtotal() + _invoiceTax() - _invoiceDiscount();
    return total < 0 ? 0.0 : total;
  }

  List<ReceiptLineItem> _invoiceReceiptLineItems() {
    return _invoiceCartItems().map((item) {
      return ReceiptLineItem(
        name: (item['name'] ?? item['productName'] ?? 'Item').toString(),
        quantity: _toDouble(item['quantity']),
        unitPrice: _toDouble(item['unitPrice'] ?? item['price']),
        total: _toDouble(item['total']),
      );
    }).toList();
  }

  Uint8List _buildThermalInvoiceBytes({
    required int paperWidth,
    String? copyLabel,
  }) {
    final auth = context.read<AuthProvider>();
    final business = context.read<BusinessProvider>().currentBusiness;
    final invoiceNumber =
        'INV-${widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final customerName = (widget.saleData['customerName'] ??
            (widget.saleData['customer'] is Map
                ? widget.saleData['customer']['name']
                : null))
        ?.toString();

    return EscPosReceiptGenerator.generateReceipt(
      businessName: widget.businessName,
      receiptNumber: invoiceNumber,
      receiptDate: DateTime.now(),
      items: _invoiceReceiptLineItems(),
      subtotal: _invoiceSubtotal(),
      tax: _invoiceTax(),
      discount: _invoiceDiscount(),
      total: _invoiceTotal(),
      paymentMethod: _getPaymentMethod(widget.saleData),
      customerName: customerName,
      cashier: auth.currentUser?.fullName,
      storeName: _receiptStoreName(),
      storeAddress: business?.address,
      storeTelephone: business?.phone,
      notes: 'Invoice slip',
      currencySymbol: 'NGN ',
      paperWidth: paperWidth,
      copyLabel: copyLabel,
      documentTitle: 'TAX INVOICE',
    );
  }

  Future<void> _printBluetoothInvoice() async {
    if (_isCheckoutLockedToReceipt) {
      await _printReceipt();
      return;
    }

    final selectedWidth = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Invoice Paper Width'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 58),
            child: const Text('58mm thermal slip'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 80),
            child: const Text('80mm thermal slip'),
          ),
        ],
      ),
    );

    if (selectedWidth == null) return;

    final thermalPrefs =
        Provider.of<ReceiptSettingsProvider>(context, listen: false)
            .receiptPreferences;
    final copiesRaw = thermalPrefs['copies'];
    final copies = (copiesRaw is int && copiesRaw > 0) ? copiesRaw : 1;
    final receipts = <Uint8List>[];

    for (var i = 0; i < copies; i++) {
      receipts.add(
        _buildThermalInvoiceBytes(
          paperWidth: selectedWidth,
          copyLabel: _copyLabelForReceipt(i, copies),
        ),
      );
    }

    setState(() {
      _isPrinting = true;
      _statusMessage = 'Preparing Bluetooth invoice print...';
      _statusColor = Colors.grey;
    });

    await _handleBluetoothPrintBytes(receipts, selectedWidth);

    if (mounted) {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _generateInvoice() async {
    if (_isEmailing) return; // Reuse the loading state
    setState(() {
      _isEmailing = true;
      _statusMessage = 'Generating invoice...';
      _statusColor = Colors.grey;
    });

    try {
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;

      if (business == null) {
        setState(() {
          _statusMessage = 'Business information not available';
          _statusColor = Colors.red;
        });
        return;
      }

      final invoiceItems = _invoiceCartItems();
      final subtotal = _invoiceSubtotal();
      final tax = _invoiceTax();
      final discount = _invoiceDiscount();
      final total = _invoiceTotal();

      // Create invoice data
      final invoiceData = {
        'businessId': business.id,
        'customerId': widget.saleData['customerId'],
        'customerName': widget.saleData['customerName'] ?? 'Customer',
        'customerEmail': widget.saleData['customerEmail'],
        'customerPhone': widget.saleData['customerPhone'],
        'invoiceNumber': 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        'items': invoiceItems,
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'total': total,
        'status': 'sent', // Mark as sent since it's generated after sale
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': auth.currentUser?.id,
        'notes': 'Generated from sale ${widget.orderId ?? 'N/A'}',
        'saleId': widget.orderId, // Link to the original sale
      };

      // Save invoice to Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('businesses')
          .doc(business.id)
          .collection('invoices')
          .add(invoiceData);

      setState(() {
        _statusMessage = 'Invoice generated successfully';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error generating invoice: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isEmailing = false);
    }
  }

  Future<void> _generatePdfInvoice() async {
    if (_pdfGenerating) return;
    setState(() {
      _pdfGenerating = true;
      _statusMessage = 'Generating PDF invoice...';
      _statusColor = Colors.grey;
    });

    try {
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);

      final cartItems = _invoiceCartItems();
      final subtotal = _invoiceSubtotal();
      final tax = _invoiceTax();
      final discount = _invoiceDiscount();
      final total = _invoiceTotal();

      final invoiceNumber = 'INV-${widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdfBytes(
        businessName: widget.businessName,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(), // Use current date for invoice
        cartItems: cartItems,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        customerName: (widget.saleData['customerName'] ?? widget.saleData['customer']?['name'] ?? 'Customer').toString(),
        customerEmail: widget.customerEmail,
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        cashierName: auth.currentUser?.fullName,
        businessLogoUrl: business?.photoUrl ?? business?.logoUrl,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );

      final filename = PdfInvoiceGenerator.getInvoiceFilename(invoiceNumber);

      if (kIsWeb) {
        web_download.downloadBytes(pdfBytes, filename, 'application/pdf');
        setState(() {
          _pdfGenerating = false;
          _pdfBytes = pdfBytes;
          _pdfFile = null;
          _lastGeneratedPdfWasInvoice = true;
          _statusMessage = 'Invoice PDF downloaded';
          _statusColor = Colors.green;
        });
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);
        setState(() {
          _pdfFile = file;
          _pdfBytes = pdfBytes;
          _pdfGenerating = false;
          _lastGeneratedPdfWasInvoice = true;
          _statusMessage = 'Invoice PDF generated';
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      setState(() {
        _pdfGenerating = false;
        _statusMessage = 'Error generating PDF invoice: $e';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _printPdfInvoice() async {
    if (_isPrinting) return;
    setState(() {
      _isPrinting = true;
      _statusMessage = widget.invoiceLockedAfterCheckout
          ? 'Preparing receipt print...'
          : 'Preparing invoice print...';
      _statusColor = Colors.grey;
    });

    try {
      if (_isCompletedSaleReceiptFlow) {
        await _generatePdf();
      }

      if (_isCompletedSaleReceiptFlow) {
        final receiptBytes = _pdfBytes ?? (_pdfFile != null ? await _pdfFile!.readAsBytes() : null);
        if (receiptBytes == null || receiptBytes.isEmpty) {
          throw Exception('Receipt PDF is not available');
        }

        final receiptName = PdfReceiptGenerator.getReceiptFilename(
          widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );

        if (kIsWeb) {
          await web_download.printPdfBytes(receiptBytes, receiptName);
        } else {
          await Printing.layoutPdf(
            name: receiptName,
            onLayout: (_) async => receiptBytes,
          );
        }

        if (!mounted) return;
        setState(() {
          _statusMessage = 'Receipt print dialog opened';
          _statusColor = Colors.green;
        });
        return;
      }

      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final invoiceNumber =
          'INV-${widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdfBytes(
        businessName: widget.businessName,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        cartItems: _invoiceCartItems(),
        subtotal: _invoiceSubtotal(),
        tax: _invoiceTax(),
        discount: _invoiceDiscount(),
        total: _invoiceTotal(),
        customerName: (widget.saleData['customerName'] ??
                (widget.saleData['customer'] is Map
                    ? widget.saleData['customer']['name']
                    : null) ??
                'Customer')
            .toString(),
        customerEmail: widget.customerEmail,
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        cashierName: auth.currentUser?.fullName,
        businessLogoUrl: business?.photoUrl ?? business?.logoUrl,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );
      final filename = PdfInvoiceGenerator.getInvoiceFilename(invoiceNumber);

      if (kIsWeb) {
        await web_download.printPdfBytes(pdfBytes, filename);
      } else {
        await Printing.layoutPdf(
          name: filename,
          onLayout: (_) async => pdfBytes,
        );
      }

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Invoice print dialog opened';
        _statusColor = Colors.green;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Invoice print failed: $e';
        _statusColor = Colors.red;
      });
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _generatePdf() async {
    if (_pdfGenerating) return;
    setState(() {
      _pdfGenerating = true;
      _statusMessage = 'Generating PDF...';
      _statusColor = Colors.grey;
    });

    try {
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final receiptProvider = Provider.of<ReceiptSettingsProvider>(context, listen: false);
      final settings = receiptProvider.receiptSettings;

      final receiptNumber = widget.orderId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

      // Build items list and calculate subtotal
      double calculatedSubtotal = 0.0;
      final itemsList = (widget.saleData['items'] as List? ?? []).map((e) {
        if (e is Map<String, dynamic>) {
          String name = 'Item';
          if (e['name'] != null && e['name'].toString().trim().isNotEmpty) {
            name = e['name'].toString();
          } else if (e['product'] is Map && e['product']['name'] != null) {
            name = e['product']['name'].toString();
          } else if (e['productName'] != null) {
            name = e['productName'].toString();
          }

          final quantityRaw = e['quantity'] ?? e['qty'] ?? e['quantity_sold'] ?? 1;
          final quantity = ThermalPrintingService.parseNum(quantityRaw);

          final priceRaw = e['price'] ?? e['unitPrice'] ?? e['unit_price'] ?? ((e['product'] is Map) ? (e['product']['price'] ?? e['product']['sellingPrice'] ?? e['product']['salePrice']) : null) ?? 0;
          var price = ThermalPrintingService.parseDouble(priceRaw);
          if (price == 0.0 && e['total'] != null) {
            final total = ThermalPrintingService.parseDouble(e['total']);
            if (total > 0 && quantity > 0) price = (total / quantity).toDouble();
          }

          // 🔥 FIX: Calculate subtotal from line totals
          final lineTotal = (e['total'] != null) ? ThermalPrintingService.parseDouble(e['total']) : (quantity * price);
          calculatedSubtotal += lineTotal;
          final unit = _extractItemUnit(e);

          return {
            'name': name,
            'quantity': quantity,
            'price': price,
            if (unit != null) 'unit': unit,
          };
        }
        return {'name': 'Item', 'quantity': 1, 'price': 0.0};
      }).toList();

      // Try to fetch server-side createdAt and workerName if order exists
      DateTime receiptDate = DateTime.now();
      String cashierName = widget.saleData['workerName'] ?? auth.currentUser?.fullName ?? 'Staff';
      try {
        final bid = business?.id;
        if (bid != null && receiptNumber.isNotEmpty) {
          final doc = await FirebaseFirestore.instance.collection('businesses').doc(bid).collection('sales').doc(receiptNumber).get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            final created = data['createdAt'];
            if (created is Timestamp) {
              receiptDate = created.toDate();
            } else if (created is DateTime) {
              receiptDate = created;
            }

            if (data['workerName'] != null && data['workerName'].toString().trim().isNotEmpty) {
              cashierName = data['workerName'].toString();
            }
          }
        }
      } catch (e) {
        debugPrint('[PostSaleActionSheet] Failed to fetch sale doc: $e');
      }

      final _customFooter = settings?.footerMessage;
      final footerWithPowered = (_customFooter?.isNotEmpty == true) ? '$_customFooter\nPowered by Manage Care' : 'Powered by Manage Care';
      final tableLabel = (widget.saleData['tableLabel'] ??
              widget.saleData['tableNo'] ??
              widget.saleData['tableNumber'] ??
              widget.saleData['table'])
          ?.toString()
          .trim();

      // Generate
      if (kIsWeb) {
        final bytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
          businessName: widget.businessName,
          storeName: _receiptStoreName(),
          receiptNumber: receiptNumber,
          receiptDate: receiptDate,
          items: itemsList,
          subtotal: widget.saleData['subtotal'] != null ? ThermalPrintingService.parseDouble(widget.saleData['subtotal']) : calculatedSubtotal,
          tax: (widget.saleData['tax'] ?? 0.0).toDouble(),
          total: (widget.saleData['total'] ?? widget.saleData['amount'] ?? 0.0).toDouble(),
          paymentMethod: _getPaymentMethod(widget.saleData),
          paymentBreakdown: _getPaymentBreakdown(widget.saleData),
          customerName: (widget.saleData['customer'] is Map) ? (widget.saleData['customer']['name'] ?? 'Customer') : (widget.saleData['customerName'] ?? 'Customer'),
          customerEmail: (widget.saleData['customer'] is Map) ? (widget.saleData['customer']['email'] ?? '') : (widget.saleData['customerEmail'] ?? ''),
          customHeader: settings?.headerNote,
          customFooter: footerWithPowered,
          paperWidth: (settings?.paperWidth ?? 58).toString(),
          cashier: cashierName,
          tableLabel: tableLabel?.isNotEmpty == true ? tableLabel : null,
          poweredByText: footerWithPowered,
          showQrCode: settings?.showQrCode ?? false,
          receiptUrlBase: settings?.receiptUrlBase,
          discount: (widget.saleData['discount'] ?? 0.0).toDouble(),
          businessLogoUrl: business?.photoUrl ?? business?.logoUrl,
          businessAddress: business?.address,
          businessPhone: business?.phone,
          businessEmail: business?.email,
          subscriptionTier: business?.subscriptionTier,
          businessClass: business?.businessClass,
        );

        setState(() {
          _pdfBytes = bytes;
          _pdfFile = null;
          _pdfGenerating = false;
          _lastGeneratedPdfWasInvoice = false;
          _statusMessage = 'PDF ready (click Save/Share)';
          _statusColor = Colors.green;
        });
      } else {
        final file = await PdfReceiptGenerator.generateReceiptPdf(
          businessName: widget.businessName,
          storeName: _receiptStoreName(),
          receiptNumber: receiptNumber,
          receiptDate: receiptDate,
          items: itemsList,
          subtotal: widget.saleData['subtotal'] != null ? ThermalPrintingService.parseDouble(widget.saleData['subtotal']) : calculatedSubtotal,
          tax: (widget.saleData['tax'] ?? 0.0).toDouble(),
          total: (widget.saleData['total'] ?? widget.saleData['amount'] ?? 0.0).toDouble(),
          paymentMethod: _getPaymentMethod(widget.saleData),
          paymentBreakdown: _getPaymentBreakdown(widget.saleData),
          customerName: (widget.saleData['customer'] is Map) ? (widget.saleData['customer']['name'] ?? 'Customer') : (widget.saleData['customerName'] ?? 'Customer'),
          customerEmail: (widget.saleData['customer'] is Map) ? (widget.saleData['customer']['email'] ?? '') : (widget.saleData['customerEmail'] ?? ''),
          customHeader: settings?.headerNote,
          customFooter: footerWithPowered,
          paperWidth: (settings?.paperWidth ?? 58).toString(),
          cashier: cashierName,
          tableLabel: tableLabel?.isNotEmpty == true ? tableLabel : null,
          poweredByText: footerWithPowered,
          showQrCode: settings?.showQrCode ?? false,
          receiptUrlBase: settings?.receiptUrlBase,
          discount: (widget.saleData['discount'] ?? 0.0).toDouble(),
          businessLogoUrl: business?.photoUrl ?? business?.logoUrl,
          businessAddress: business?.address,
          businessPhone: business?.phone,
          businessEmail: business?.email,
          subscriptionTier: business?.subscriptionTier,
          businessClass: business?.businessClass,
        );

        final bytes = await file.readAsBytes();
        setState(() {
          _pdfFile = file;
          _pdfBytes = bytes;
          _pdfGenerating = false;
          _lastGeneratedPdfWasInvoice = false;
          _statusMessage = 'PDF generated';
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      setState(() {
        _pdfGenerating = false;
        _statusMessage = 'Error generating PDF: $e';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _previewPdf() async {
    if (_isPreviewing) return;
    setState(() {
      _isPreviewing = true;
      _statusMessage = 'Generating PDF preview...';
      _statusColor = Colors.grey;
    });

    try {
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final receiptProvider = Provider.of<ReceiptSettingsProvider>(context, listen: false);
      final settings = receiptProvider.receiptSettings;

      final receiptNumber = widget.orderId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

      // Build items list and calculate subtotal (same logic as in _generatePdf)
      double calculatedSubtotal = 0.0;
      final itemsList = (widget.saleData['items'] as List? ?? []).map((e) {
        if (e is Map<String, dynamic>) {
          String name = 'Item';
          if (e['name'] != null && e['name'].toString().trim().isNotEmpty) {
            name = e['name'].toString();
          } else if (e['product'] is Map && e['product']['name'] != null) {
            name = e['product']['name'].toString();
          } else if (e['productName'] != null) {
            name = e['productName'].toString();
          }

          final quantityRaw = e['quantity'] ?? e['qty'] ?? e['quantity_sold'] ?? 1;
          final quantity = ThermalPrintingService.parseNum(quantityRaw);

          final priceRaw = e['price'] ?? e['unitPrice'] ?? e['unit_price'] ?? ((e['product'] is Map) ? (e['product']['price'] ?? e['product']['sellingPrice'] ?? e['product']['salePrice']) : null) ?? 0;
          var price = ThermalPrintingService.parseDouble(priceRaw);
          if (price == 0.0 && e['total'] != null) {
            final total = ThermalPrintingService.parseDouble(e['total']);
            if (total > 0 && quantity > 0) price = (total / quantity).toDouble();
          }

          // 🔥 FIX: Calculate subtotal from line totals
          final lineTotal = (e['total'] != null) ? ThermalPrintingService.parseDouble(e['total']) : (quantity * price);
          calculatedSubtotal += lineTotal;
          final unit = _extractItemUnit(e);

          return {
            'name': name,
            'quantity': quantity,
            'price': price,
            if (unit != null) 'unit': unit,
          };
        }
        return {'name': 'Item', 'quantity': 1, 'price': 0.0};
      }).toList();

      DateTime receiptDate = DateTime.now();
      String cashierName = widget.saleData['workerName'] ?? auth.currentUser?.fullName ?? 'Staff';
      try {
        final bid = business?.id;
        if (bid != null && receiptNumber.isNotEmpty) {
          final doc = await FirebaseFirestore.instance.collection('businesses').doc(bid).collection('sales').doc(receiptNumber).get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            final created = data['createdAt'];
            if (created is Timestamp) receiptDate = created.toDate();
            if (data['workerName'] != null && data['workerName'].toString().trim().isNotEmpty) cashierName = data['workerName'].toString();
          }
        }
      } catch (_) {}

      final _customFooter = settings?.footerMessage;
      final footerWithPowered = (_customFooter?.isNotEmpty == true) ? '$_customFooter\nPowered by Manage Care' : 'Powered by Manage Care';

      final bytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
        businessName: widget.businessName,
        receiptNumber: receiptNumber,
        receiptDate: receiptDate,
        items: itemsList,
        subtotal: widget.saleData['subtotal'] != null ? ThermalPrintingService.parseDouble(widget.saleData['subtotal']) : calculatedSubtotal,
        tax: (widget.saleData['tax'] ?? 0.0).toDouble(),
        total: (widget.saleData['total'] ?? widget.saleData['amount'] ?? 0.0).toDouble(),
        paymentMethod: widget.saleData['paymentMethod'] ?? 'Cash',
        paymentBreakdown: (widget.saleData['paymentBreakdown'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList(),
        customerName: (widget.saleData['customer'] is Map) ? (widget.saleData['customer']['name'] ?? 'Customer') : (widget.saleData['customerName'] ?? 'Customer'),
        customerEmail: (widget.saleData['customer'] is Map) ? (widget.saleData['customer']['email'] ?? '') : (widget.saleData['customerEmail'] ?? ''),
        customHeader: settings?.headerNote,
        customFooter: footerWithPowered,
        paperWidth: (settings?.paperWidth ?? 58).toString(),
        cashier: cashierName,
        poweredByText: footerWithPowered,
        showQrCode: settings?.showQrCode ?? false,
        receiptUrlBase: settings?.receiptUrlBase,
        discount: (widget.saleData['discount'] ?? 0.0).toDouble(),
        businessLogoUrl: business?.photoUrl ?? business?.logoUrl,
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );
      _lastGeneratedPdfWasInvoice = false;

      setState(() {
        _statusMessage = 'PDF preview ready';
        _statusColor = Colors.green;
        _isPreviewing = false;
      });

      // Open preview page (PdfPreviewPage expects List<int>)
      if (bytes.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfPreviewPage(pdfBytes: bytes.toList())));
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'PDF preview failed: $e';
        _statusColor = Colors.red;
        _isPreviewing = false;
      });
    }
  }


  Future<void> _shareReceipt() async {
    setState(() => _isSharing = true);
    try {
      final success = await ReceiptUtility.shareReceiptAsText(
        receiptText: widget.receiptText,
        businessName: widget.businessName,
      );
      setState(() {
        _statusMessage = success ? 'Receipt shared!' : 'Share failed';
        _statusColor = success ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isSharing = false);
    }
  }

  Future<void> _emailReceipt() async {
    setState(() => _isEmailing = true);
    try {
      final businessProvider =
          Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;
      final isValid = AccessControl.canUseEmailAndPrint(context);

      if (!isValid) {
        setState(() {
          _statusMessage =
              'Email receipts require an active Professional subscription';
          _statusColor = Colors.orange;
        });
        return;
      }

      final recipient = widget.customerEmail ?? business?.email;
      if (recipient == null || recipient.isEmpty) {
        setState(() {
          _statusMessage = 'No recipient email available';
          _statusColor = Colors.red;
        });
        return;
      }

      final emailService = Provider.of<EmailService>(context, listen: false);
      // Include structured items when possible to avoid placeholder names
      final items = (widget.saleData['items'] as List? ?? []).map((e) {
        if (e is Map<String, dynamic>) {
          return {
            'name': _displaySaleItemName(e),
            'quantity': e['quantity'] ?? e['qty'] ?? 1,
            'price': (e['price'] ?? e['unitPrice'] ?? 0).toDouble(),
          };
        }
        return {'name': 'Item', 'quantity': 1, 'price': 0.0};
      }).toList();

      final paymentBreakdown = (widget.saleData['paymentBreakdown'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      bool success = false;

      // If a locally generated PDF exists, prefer sending it as an attachment
      final emailData = {
        'orderId': widget.orderId,
        'businessName': widget.businessName,
        'customerName': widget.saleData['customerName'] ?? widget.saleData['customer'] is Map ? widget.saleData['customer']['name'] : null,
      };

      try {
        final attached = await _attachPdfToEmailIfAvailable(emailService, recipient, emailData);
        if (attached) {
          success = true;
        } else {
          success = await emailService.sendReceiptEmail(
            recipient: recipient,
            businessName: widget.businessName,
            receiptText: widget.receiptText,
            orderId: widget.orderId,
            items: items.cast<Map<String, dynamic>>(),
            subtotal: (widget.saleData['subtotal'] ?? 0.0).toDouble(),
            tax: (widget.saleData['tax'] ?? 0.0).toDouble(),
            total: (widget.saleData['total'] ?? 0.0).toDouble(),
            paymentMethod: _getPaymentMethod(widget.saleData),
              paymentBreakdown: paymentBreakdown ?? _getPaymentBreakdown(widget.saleData),
          );
        }
      } catch (e) {
        debugPrint('Email send with attachment fallback failed: $e');
        success = false;
      }

      // Log analytics event
      final analyticsService = AnalyticsService();
      await analyticsService.logEvent('receipt_emailed', {
        'order_id': widget.orderId,
        'business_name': widget.businessName,
        'recipient': recipient,
      });

      setState(() {
        _statusMessage = success ? 'Receipt emailed!' : 'Email send failed';
        _statusColor = success ? Colors.green : Colors.red;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isEmailing = false);
    }
  }

  Future<void> _printReceipt() async {
    // 🔥 NEW: Show paper width selection dialog
    final selectedWidth = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Paper Width'),
        content: const Text('Which paper width is your printer configured for?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 58),
            child: const Text('58mm (Standard)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 80),
            child: const Text('80mm (Wide)'),
          ),
        ],
      ),
    );

    if (selectedWidth == null) {
      return; // User cancelled
    }

    setState(() => _isPrinting = true);
    try {
      // Ensure Bluetooth permissions first (for non-web platforms)
      if (!kIsWeb) {
        final permsOk = await ThermalPrintingService.ensureBluetoothPermissions();
        if (!permsOk) {
          setState(() {
            _statusMessage = 'Bluetooth permissions denied. Please grant in settings.';
            _statusColor = Colors.orange;
          });
          return;
        }
      }

      final business = Provider.of<BusinessProvider>(context, listen: false).currentBusiness;

      // 🔥 OPTIMIZED: Use user-selected paper width instead of settings
      final paperWidth = selectedWidth;

      // Prepare receipt items and totals
      final authProvider = context.read<AuthProvider>();
      final cashierName = widget.saleData['workerName'] ?? authProvider.currentUser?.fullName ?? 'Staff';

      final itemsList = <ReceiptLineItem>[];
      double subtotal = 0.0;
      final rawItems = (widget.saleData['items'] as List? ?? []);

      for (var e in rawItems) {
        String name = 'Item';
        if (e is Map<String, dynamic>) {
          name = _displaySaleItemName(e);

          final quantityRaw = e['quantity'] ?? e['qty'] ?? e['quantity_sold'] ?? 1;
          final quantity = ThermalPrintingService.parseNum(quantityRaw).toDouble();

          final priceRaw = e['price'] ?? e['unitPrice'] ?? e['unit_price'] ??
              ((e['product'] is Map) ? (e['product']['price'] ?? e['product']['sellingPrice'] ?? e['product']['salePrice']) : null) ?? 0;
          var price = ThermalPrintingService.parseDouble(priceRaw);

          if ((price == 0.0) && e['total'] != null) {
            final total = ThermalPrintingService.parseDouble(e['total']);
            if (total > 0 && quantity > 0) {
              price = (total / quantity).toDouble();
            }
          }

          final lineTotal = (e['total'] != null) ? ThermalPrintingService.parseDouble(e['total']) : (quantity * price);
          subtotal += lineTotal;

          // Extract unit information if available
          final unitRaw = _extractItemUnit(e);

          itemsList.add(
            ReceiptLineItem(
              name: name,
              quantity: quantity,
              unitPrice: price,
              total: lineTotal,
              unit: unitRaw,
              pricingMode: _extractPricingMode(e),
            ),
          );
        }
      }

      final tax = (widget.saleData['tax'] != null) ? ThermalPrintingService.parseDouble(widget.saleData['tax']) : 0.0;
      final discount = (widget.saleData['discount'] != null) ? ThermalPrintingService.parseDouble(widget.saleData['discount']) : 0.0;
      final totalAmount = ThermalPrintingService.parseDouble(widget.saleData['total'] ?? subtotal);

      // Generate ESC/POS bytes for printing (Bluetooth)
      final invoiceUrl = (widget.orderId != null && widget.orderId!.isNotEmpty)
          ? 'https://managecare.app/invoice/${widget.orderId}'
          : '';

      // Determine number of copies (use thermal prefs if available, else default 2)
      final thermalPrefs = Provider.of<ReceiptSettingsProvider>(context, listen: false).receiptPreferences;
      final copiesRaw = thermalPrefs['copies'];
      final copies = (copiesRaw is int && copiesRaw > 0) ? copiesRaw : 2;

      final receipts = <Uint8List>[];
      for (var i = 0; i < copies; i++) {
        final copyLabel = _copyLabelForReceipt(i, copies);

        final bytes = EscPosReceiptGenerator.generateReceipt(
          businessName: widget.businessName,
          receiptNumber: widget.orderId ?? 'N/A',
          receiptDate: DateTime.now(),
          items: itemsList,
          subtotal: subtotal,
          tax: tax,
          discount: discount,
          total: totalAmount,
          paymentMethod: widget.saleData['paymentMethod'] ?? 'Cash',
          customerName: (widget.saleData['customer'] is Map)
              ? (widget.saleData['customer']['name'] ?? widget.saleData['customerName'])
                    ?.toString()
              : widget.saleData['customerName']?.toString(),
          cashier: cashierName,
          storeName: _receiptStoreName(),
          // 🔥 NEW: Include business address and phone on receipt
          storeAddress: business?.city != null && business!.city!.isNotEmpty ? business.city : null,
          storeTelephone: business?.phone != null && business!.phone!.isNotEmpty ? business.phone : null,
          invoiceUrl: invoiceUrl,
          showQrCode: invoiceUrl.isNotEmpty,
          paperWidth: paperWidth,
          copyLabel: copyLabel,
        );
        receipts.add(bytes);
      }

      // Bluetooth printing (this method is only for Bluetooth)
      await _handleBluetoothPrintBytes(receipts, paperWidth);

    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString().split('\n').first}';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isPrinting = false);
    }
  }


  Future<void> _handleBluetoothPrint(String thermalText, int paperWidth) async {
    try {
      // Initialize thermal printing service first
      setState(() => _statusMessage = 'Initializing printer service...');
      final thermalService = ThermalPrintingService();
      await thermalService.initialize();

      // Get printer MAC address
      String? targetMac;
      final settings = Provider.of<ReceiptSettingsProvider>(context, listen: false).receiptSettings;
      
      targetMac = settings?.defaultPrinterMac;
      
      if ((targetMac == null || targetMac.isEmpty) && !kIsWeb) {
        setState(() => _statusMessage = 'Scanning for printers...');
        final devices = await thermalService.getAvailablePrinters();
        
        if (devices.isEmpty) {
          setState(() {
            _statusMessage = 'No Bluetooth printer found. Pair a printer first.';
            _statusColor = Colors.orange;
          });
          return;
        }

        String? choice;
        if (devices.length == 1) {
          choice = devices.first.address;
        } else {
          choice = await showDialog<String?>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Select Printer'),
              children: devices.map((d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d.address),
                child: Text(d.name.isNotEmpty ? d.name : d.address),
              )).toList(),
            ),
          );
        }

        if (choice == null) {
          setState(() {
            _statusMessage = 'Printer selection cancelled.';
            _statusColor = Colors.orange;
          });
          return;
        }
        final selectedPrinter = devices.firstWhere((d) => d.address == choice);
        final connected = await thermalService.connectToPrinter(selectedPrinter);
        if (!connected) {
          setState(() {
            _statusMessage = 'Failed to connect to printer. Check power.';
            _statusColor = Colors.orange;
          });
          return;
        }
        targetMac = selectedPrinter.address;
      }

      if (targetMac == null || targetMac.isEmpty) {
        setState(() {
          _statusMessage = 'No printer selected or available.';
          _statusColor = Colors.orange;
        });
        return;
      }

      // Small delay to ensure connection is stable
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Verify printer is still connected before printing
      setState(() => _statusMessage = 'Verifying printer connection...');
      final status = await thermalService.printerManager.checkPrinterStatus();
      if (status != PrinterStatus.connected) {
        setState(() {
          _statusMessage = 'Printer not connected. Check power & Bluetooth.';
          _statusColor = Colors.orange;
        });
        return;
      }
      
      // Print receipt
      setState(() => _statusMessage = 'Printing receipt...');
      // This path is replaced by _handleBluetoothPrintBytes for raw ESC/POS bytes
      // (kept for reference)
      
      // The flow continues in _handleBluetoothPrintBytes
    } catch (e) {
      setState(() {
        _statusMessage = 'Print error: ${e.toString().split('\n').first}';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _handleBluetoothPrintBytes(List<Uint8List> receipts, int paperWidth) async {
    try {
      setState(() => _statusMessage = 'Initializing printer service...');
      final thermalService = ThermalPrintingService();
      await thermalService.initialize();

      // Get printer MAC address from settings
      String? targetMac;
      final settings = Provider.of<ReceiptSettingsProvider>(context, listen: false).receiptSettings;
      targetMac = settings?.defaultPrinterMac;

      // If a default printer is configured, confirm with the user or allow selection
      if ((targetMac != null && targetMac.isNotEmpty) && !kIsWeb) {
        setState(() => _statusMessage = 'Checking default printer...');
        final devices = await thermalService.getAvailablePrinters();
        final defaultPrinter = devices.firstWhere((d) => d.address == targetMac, orElse: () => ThermalPrinterDevice(address: targetMac!, name: '', type: 'bluetooth'));

        final choice = await showDialog<String?>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Printer Selection'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'use_default'),
                child: Text('Use default printer: ${defaultPrinter.name.isNotEmpty ? defaultPrinter.name : defaultPrinter.address}'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'choose_another'),
                child: const Text('Choose another printer'),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (choice == 'use_default') {
          // Try to connect to the default printer (discovered or by address)
          if (defaultPrinter.name.isEmpty) {
            final defaultMac = targetMac!;
            final found = devices.firstWhere((d) => d.address == defaultMac, orElse: () => ThermalPrinterDevice(address: defaultMac, name: defaultMac, type: 'bluetooth'));
            final connected = await thermalService.connectToPrinter(found);
            if (!connected) {
              setState(() {
                _statusMessage = 'Failed to connect to default printer';
                _statusColor = Colors.orange;
              });
              return;
            }
          } else {
            final connected = await thermalService.connectToPrinter(defaultPrinter);
            if (!connected) {
              setState(() {
                _statusMessage = 'Failed to connect to default printer';
                _statusColor = Colors.orange;
              });
              return;
            }
          }
          // Proceed using connected default
        } else if (choice == 'choose_another') {
          // Clear default to force discovery below
          targetMac = null;
        } else {
          setState(() {
            _statusMessage = 'Printer selection cancelled.';
            _statusColor = Colors.orange;
          });
          return;
        }
      }

      if ((targetMac == null || targetMac.isEmpty) && !kIsWeb) {
        setState(() => _statusMessage = 'Scanning for printers...');
        final devices = await thermalService.getAvailablePrinters();
        if (devices.isEmpty) {
          setState(() {
            _statusMessage = 'No Bluetooth printer found. Pair a printer first.';
            _statusColor = Colors.orange;
          });
          return;
        }

        String? choice;
        if (devices.length == 1) {
          choice = devices.first.address;
        } else {
          choice = await showDialog<String?>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Select Printer'),
              children: devices.map((d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d.address),
                child: Text(d.name.isNotEmpty ? d.name : d.address),
              )).toList(),
            ),
          );
        }

        if (choice == null) {
          setState(() {
            _statusMessage = 'Printer selection cancelled.';
            _statusColor = Colors.orange;
          });
          return;
        }
        final selectedPrinter = devices.firstWhere((d) => d.address == choice);
        final connected = await thermalService.connectToPrinter(selectedPrinter);
        if (!connected) {
          setState(() {
            _statusMessage = 'Failed to connect to printer. Check power.';
            _statusColor = Colors.orange;
          });
          return;
        }
      }

      // Small delay to ensure connection
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _statusMessage = 'Verifying printer connection...');
      final status = await thermalService.printerManager.checkPrinterStatus();
      if (status != PrinterStatus.connected) {
        setState(() {
          _statusMessage = 'Printer not connected. Check power & Bluetooth.';
          _statusColor = Colors.orange;
        });
        return;
      }

      // Send multiple receipt copies
      var printedCount = 0;
      String? skippedCopyName;
      String? failedCopyName;
      for (var i = 0; i < receipts.length; i++) {
        final copyName = _copyNameForDisplay(i, receipts.length);

        if (i > 0) {
          final shouldPrint = await _confirmPrintAdditionalCopy(copyName);
          if (!shouldPrint) {
            skippedCopyName = copyName;
            break;
          }
        }

        final currentStatus = await thermalService.printerManager.checkPrinterStatus();
        if (currentStatus != PrinterStatus.connected) {
          setState(() {
            _statusMessage = 'Printer not connected. Check power & Bluetooth.';
            _statusColor = Colors.orange;
          });
          return;
        }

        setState(() => _statusMessage = 'Printing ${copyName.toLowerCase()}...');
        final success = await thermalService.printRawBytes(receipts[i]);
        await Future.delayed(const Duration(milliseconds: 300));
        if (!success) {
          failedCopyName = copyName;
          break;
        }
        printedCount++;
      }

      setState(() {
        if (failedCopyName != null) {
          _statusMessage = 'Failed to print ${failedCopyName.toLowerCase()}. Check printer power & connection.';
          _statusColor = Colors.red;
        } else if (skippedCopyName != null) {
          if (printedCount == 1 && receipts.length >= 2) {
            final firstCopyName = _copyNameForDisplay(0, receipts.length);
            _statusMessage = '$firstCopyName printed. $skippedCopyName skipped.';
          } else {
            final copyText = printedCount == 1 ? 'copy' : 'copies';
            _statusMessage = '$printedCount receipt $copyText printed. $skippedCopyName skipped.';
          }
          _statusColor = Colors.green;
        } else if (printedCount == receipts.length) {
          if (receipts.length == 2) {
            _statusMessage = 'Customer and business copies printed successfully!';
          } else if (receipts.length == 1) {
            _statusMessage = 'Receipt printed successfully!';
          } else {
            _statusMessage = '$printedCount receipt copies printed successfully!';
          }
          _statusColor = Colors.green;
        } else {
          _statusMessage = 'Print failed. Check printer power & connection.';
          _statusColor = Colors.red;
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Print error: ${e.toString().split('\n').first}';
        _statusColor = Colors.red;
      });
    }
  }

  /// Web-optimized print handler - uses browser print dialog
  Future<void> _printReceiptWeb() async {
    if (kIsWeb) {
      setState(() => _isPrinting = true);
      try {
        if (_isCompletedSaleReceiptFlow) {
          await _generatePdf();
        }

        // For web, show print preview using browser's print dialog
        if (_pdfBytes != null && _pdfBytes!.isNotEmpty) {
          try {
            // Use web_download service for efficient browser printing
            await web_download.printPdfBytes(_pdfBytes!, 'Receipt_${widget.orderId}');
            setState(() {
              _statusMessage = 'Print dialog opened';
              _statusColor = Colors.green;
            });
          } catch (e) {
            setState(() {
              _statusMessage = 'Print error: $e';
              _statusColor = Colors.red;
            });
          }
        } else {
          setState(() {
            _statusMessage = 'PDF not ready. Please generate receipt first.';
            _statusColor = Colors.orange;
          });
        }
      } finally {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _printReceiptUsb() async {
    setState(() => _isPrinting = true);

    try {
      // Build sale model from widget data
      (widget.saleData['items'] as List<dynamic>?)?.map((it) {
        try {
          final id = (it is Map && (it['productId'] ?? it['id']) != null) ? (it['productId'] ?? it['id']).toString() : '';
          final name = (it is Map) ? (it['name'] ?? it['productName'] ?? 'Item').toString() : it.toString();
          final qty = (it is Map) ? ((it['quantity'] ?? it['qty'] ?? 1) as num).toDouble() : 1.0;
          final price = (it is Map) ? ((it['unitPrice'] ?? it['price'] ?? it['unit_price'] ?? 0) as num).toDouble() : 0.0;
          final total = (it is Map) ? ((it['total'] ?? (qty * price)) as num).toDouble() : 0.0;
          return SaleItem(id: id, productId: id, productName: name, quantity: qty, unitPrice: price, total: total);
        } catch (_) {
          return SaleItem(id: '', productId: '', productName: 'Item', quantity: 1.0, unitPrice: 0.0, total: 0.0);
        }
      }).toList() ?? [];

      // Note: saleModel could be used for analytics or history tracking in future
      /* final saleModel = SaleModel(
        id: widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        businessId: businessId,
        customerId: (widget.saleData['customerId'] ?? (widget.saleData['customer'] is Map ? widget.saleData['customer']['id'] : null))?.toString(),
        customerName: (widget.saleData['customerName'] ?? (widget.saleData['customer'] is Map ? widget.saleData['customer']['name'] : null))?.toString(),
        items: items,
        totalAmount: ((widget.saleData['subtotal'] ?? widget.saleData['total'] ?? 0) as num).toDouble(),
        discountAmount: ((widget.saleData['discount'] ?? 0) as num).toDouble(),
        taxAmount: ((widget.saleData['tax'] ?? 0) as num).toDouble(),
        finalAmount: ((widget.saleData['total'] ?? widget.saleData['amount'] ?? 0) as num).toDouble(),
        paymentMethod: (widget.saleData['paymentMethod'] ?? 'cash').toString(),
        status: (widget.saleData['status'] ?? 'completed').toString(),
        receiptNumber: widget.orderId?.toString(),
        notes: widget.saleData['notes']?.toString(),
        createdBy: widget.saleData['workerName']?.toString() ?? auth.currentUser?.fullName ?? 'Staff',
        createdAt: parseTimestamp(widget.saleData['createdAt']),
      ); */

      // Print using thermal printing service
      setState(() {
        _statusMessage = 'Receipt printed successfully!';
        _statusColor = Colors.green;
      });
    } catch (e) {
      debugPrint('[PostSaleActionSheet] Print error: $e');
      setState(() {
        _statusMessage = 'Print error: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _savePdf() async {
    try {
      if (_isCompletedSaleReceiptFlow) {
        await _generatePdf();
      }

      if (kIsWeb) {
        if (_pdfBytes != null) {
          final filename = PdfReceiptGenerator.getReceiptFilename(widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString());
          web_download.downloadBytes(_pdfBytes!, filename, 'application/pdf');
          setState(() { _statusMessage = 'PDF downloaded'; _statusColor = Colors.green; });
        } else {
          setState(() { _statusMessage = 'No PDF available to download'; _statusColor = Colors.red; });
        }
        return;
      }

      if (_pdfFile != null) {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final dest = File('${downloads.path}/${p.basename(_pdfFile!.path)}');
          await _pdfFile!.copy(dest.path);
          setState(() { _statusMessage = 'PDF saved to Downloads'; _statusColor = Colors.green; });
          return;
        }
      }

      if (_pdfBytes != null) {
        final saved = await ReceiptUtility.downloadReceiptAsPDF(pdfData: _pdfBytes!, fileName: ReceiptUtility.generateReceiptFileName(businessName: widget.businessName, orderId: widget.orderId));
        setState(() { _statusMessage = saved ? 'PDF saved' : 'Failed to save PDF'; _statusColor = saved ? Colors.green : Colors.red; });
        return;
      }

      setState(() { _statusMessage = 'No PDF available'; _statusColor = Colors.red; });
    } catch (e) {
      setState(() { _statusMessage = 'Error saving PDF: $e'; _statusColor = Colors.red; });
    }
  }

  Future<void> _sharePdf() async {
    try {
      if (_isCompletedSaleReceiptFlow) {
        await _generatePdf();
      }

      if (kIsWeb) {
        if (_pdfBytes != null) {
          final filename = PdfReceiptGenerator.getReceiptFilename(widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString());
          web_download.downloadBytes(_pdfBytes!, filename, 'application/pdf');
          setState(() { _statusMessage = 'PDF downloaded — open to share'; _statusColor = Colors.green; });
          return;
        }
        setState(() { _statusMessage = 'No PDF available to share'; _statusColor = Colors.red; });
        return;
      }

      File? fileToShare = _pdfFile;
      if (fileToShare == null && _pdfBytes != null) {
        final temp = await getTemporaryDirectory();
        final f = File('${temp.path}/${ReceiptUtility.generateReceiptFileName(businessName: widget.businessName, orderId: widget.orderId)}.pdf');
        await f.writeAsBytes(_pdfBytes!);
        fileToShare = f;
      }

      if (fileToShare != null && await fileToShare.exists()) {
        final result = await Share.shareXFiles([XFile(fileToShare.path)], text: 'Receipt from ${widget.businessName}', subject: '${widget.businessName} Receipt');
        setState(() { _statusMessage = result.status == ShareResultStatus.success ? 'Receipt shared' : 'Share cancelled'; _statusColor = result.status == ShareResultStatus.success ? Colors.green : Colors.orange; });
      } else {
        setState(() { _statusMessage = 'No PDF file to share'; _statusColor = Colors.red; });
      }
    } catch (e) {
      setState(() { _statusMessage = 'Error sharing PDF: $e'; _statusColor = Colors.red; });
    }
  }

  Future<bool> _attachPdfToEmailIfAvailable(EmailService emailService, String recipient, Map<String, dynamic> data) async {
    try {
      if (_pdfFile != null && await _pdfFile!.exists()) {
        return await emailService.sendTemplateEmail('order', recipient, data, attachments: [_pdfFile!]);
      }
      if (_pdfBytes != null) {
        // Fall back: upload bytes and include URL
        final temp = await getTemporaryDirectory();
        final f = File('${temp.path}/${ReceiptUtility.generateReceiptFileName(businessName: widget.businessName, orderId: widget.orderId)}.pdf');
        await f.writeAsBytes(_pdfBytes!);
        return await emailService.sendTemplateEmail('order', recipient, data, attachments: [f]);
      }
    } catch (e) {
      debugPrint('Attach PDF to email failed: $e');
    }
    return false;
  }


  void _updateItemPrice(int index, double newPrice) {
    final auth = context.read<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    if (!auth.isOwnerUser && !WorkerPermissions.canEditPrice(role)) {
      return;
    }
    if (newPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price cannot be negative'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _editableItems[index]['price'] = newPrice;
      _editableItems[index]['total'] = newPrice * (_editableItems[index]['quantity'] ?? 1);
    });
  }

  void _updateDiscount(double newDiscount) {
    final auth = context.read<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    if (!auth.isOwnerUser && !WorkerPermissions.canApplyDiscount(role)) {
      return;
    }
    setState(() {
      _editableDiscount = newDiscount;
    });
  }

  void _removeItem(int index) {
    final auth = context.read<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    if (!auth.isOwnerUser && !WorkerPermissions.canEditPrice(role)) {
      return;
    }
    setState(() {
      _editableItems.removeAt(index);
    });
  }

  double _calculateSubtotal() {
    return _editableItems.fold(0.0, (sum, item) => sum + (item['total'] ?? 0.0));
  }

  double _calculateTotal() {
    final subtotal = _calculateSubtotal();
    return subtotal - _editableDiscount + _editableTax;
  }

  /// Auto-generate invoice PDF and show print/share dialog
  Future<void> _autoGenerateAndPromptInvoice() async {
    if (_isCompletedSaleReceiptFlow) {
      await _generatePdf();
      return;
    }

    if (_invoiceDialogShown || _autoGeneratingInvoice) return;
    
    setState(() => _autoGeneratingInvoice = true);

    try {
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (business == null || !mounted) {
        setState(() => _autoGeneratingInvoice = false);
        return;
      }

      // Generate invoice PDF
      final invoiceNumber =
          'INV-${widget.orderId ?? DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicePdfBytes(
        businessName: widget.businessName,
        invoiceNumber: invoiceNumber,
        invoiceDate: DateTime.now(),
        cartItems: _invoiceCartItems(),
        subtotal: _invoiceSubtotal(),
        tax: _invoiceTax(),
        discount: _invoiceDiscount(),
        total: _invoiceTotal(),
        customerName: (widget.saleData['customerName'] ??
                (widget.saleData['customer'] is Map
                    ? widget.saleData['customer']['name']
                    : null) ??
                'Customer')
            .toString(),
        customerEmail: widget.customerEmail,
        businessAddress: business.address,
        businessPhone: business.phone,
        businessEmail: business.email,
        cashierName: auth.currentUser?.fullName,
        businessLogoUrl: business.photoUrl ?? business.logoUrl,
        subscriptionTier: business.subscriptionTier,
        businessClass: business.businessClass,
      );

      if (!mounted) return;
      setState(() {
        _pdfBytes = pdfBytes;
        _pdfGenerating = false;
        _autoGeneratingInvoice = false;
        _invoiceDialogShown = true;
      });

      // Show print/share dialog
      if (mounted) {
        _showInvoicePrintShareDialog(invoiceNumber, pdfBytes);
      }
    } catch (e) {
      debugPrint('[PostSaleActionSheet] Error auto-generating invoice: $e');
      if (mounted) {
        setState(() {
          _autoGeneratingInvoice = false;
          _invoiceDialogShown = true;
        });
      }
    }
  }

  /// Show dialog asking user to print or share the invoice
  Future<void> _showInvoicePrintShareDialog(
      String invoiceNumber, Uint8List pdfBytes) async {
    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Invoice Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice #: $invoiceNumber'),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do with this invoice?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'share'),
            child: const Text('Share'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, 'print'),
            child: const Text('Print'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    // Handle user selection
    if (action == 'print') {
      await _handleInvoicePrint(pdfBytes, invoiceNumber);
    } else if (action == 'share') {
      await _handleInvoiceShare(pdfBytes, invoiceNumber);
    }
    // Note: Sale is NOT marked as completed here - user can still share/print
    // without completing the sale. Sale will be completed when they click "Done"
  }

  /// Handle invoice printing
  Future<void> _handleInvoicePrint(
      Uint8List pdfBytes, String invoiceNumber) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      if (kIsWeb) {
        await web_download.printPdfBytes(pdfBytes, invoiceNumber);
        if (mounted) {
          setState(() {
            _statusMessage = 'Print dialog opened';
            _statusColor = Colors.green;
          });
        }
      } else {
        await Printing.layoutPdf(
          name: invoiceNumber,
          onLayout: (_) async => pdfBytes,
        );
        if (mounted) {
          setState(() {
            _statusMessage = 'Print dialog opened';
            _statusColor = Colors.green;
          });
        }
      }
    } catch (e) {
      debugPrint('[PostSaleActionSheet] Print error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Print failed: $e';
          _statusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  /// Handle invoice sharing
  Future<void> _handleInvoiceShare(
      Uint8List pdfBytes, String invoiceNumber) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final filename =
          PdfInvoiceGenerator.getInvoiceFilename(invoiceNumber);

      if (kIsWeb) {
        web_download.downloadBytes(pdfBytes, filename, 'application/pdf');
        if (mounted) {
          setState(() {
            _statusMessage = 'Invoice downloaded';
            _statusColor = Colors.green;
          });
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Invoice: $invoiceNumber',
          subject: 'Invoice $invoiceNumber',
        );
        if (mounted) {
          setState(() {
            _statusMessage = 'Invoice shared';
            _statusColor = Colors.green;
          });
        }
      }
    } catch (e) {
      debugPrint('[PostSaleActionSheet] Share error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Share failed: $e';
          _statusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  /// Mark the sale as completed in the system
  void _markSaleCompleted() {
    try {
      // Update sale status to completed
      if (widget.saleData['status'] == 'draft') {
        widget.saleData['status'] = 'completed';
      }
      debugPrint('[PostSaleActionSheet] Sale marked as completed');
    } catch (e) {
      debugPrint('[PostSaleActionSheet] Error marking sale as completed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '[PostSaleActionSheet] Building UI for orderId: ${widget.orderId}');
    final auth = context.watch<AuthProvider>();
    final currentRole = auth.currentUser?.role ?? '';
    final canEditPrice =
      auth.isOwnerUser || WorkerPermissions.canEditPrice(currentRole);
    final canApplyDiscount =
      auth.isOwnerUser || WorkerPermissions.canApplyDiscount(currentRole);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Receipt Actions', style: AppTextStyles.heading5),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_statusColor ?? Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _statusColor ?? Colors.grey),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          _statusColor == Colors.green
                              ? Icons.check_circle
                              : Icons.info,
                          color: _statusColor),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(_statusMessage!,
                              style: AppTextStyles.body2)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Edit Sale Items Section
              if (widget.allowEditing &&
                  (canEditPrice || canApplyDiscount)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Edit Sale Items', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            canEditPrice
                                ? 'Owner Price Access'
                                : 'Manager Discount Access',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.blue,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Items List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _editableItems.length,
                        itemBuilder: (context, index) {
                          final item = _editableItems[index];
                          final name = item['productName'] ?? item['name'] ?? 'Item';
                          final quantity = item['quantity'] ?? 1;
                          final price = item['price'] ?? 0.0;
                          final total = item['total'] ?? (price * quantity);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTextStyles.body2.copyWith(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text('Qty: $quantity',
                                          style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                if (canEditPrice) ...[
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue: price.toStringAsFixed(2),
                                      keyboardType: TextInputType.text,
                                      inputFormatters: [
                                        DecimalInputFormatter(),
                                      ],
                                      textAlign: TextAlign.right,
                                      style: AppTextStyles.body2,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                      ),
                                      onChanged: (value) {
                                        final newPrice =
                                            double.tryParse(value) ?? price;
                                        _updateItemPrice(index, newPrice);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  formatCurrency(total),
                                  style: AppTextStyles.body2.copyWith(
                                      fontWeight: FontWeight.w600),
                                ),
                                if (canEditPrice)
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _removeItem(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Discount and Tax editing
                      if (canApplyDiscount)
                        Column(
                          children: [
                            Row(
                              children: [
                                const Text('Discount: ',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w500)),
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                        _editableDiscount.toStringAsFixed(2),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    style: AppTextStyles.body2,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                    ),
                                    onChanged: (value) {
                                      final newDiscount =
                                          double.tryParse(value) ??
                                              _editableDiscount;
                                      _updateDiscount(newDiscount);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Subtotal: ${formatCurrency(_calculateSubtotal())}',
                                  style: AppTextStyles.body2,
                                ),
                                const Spacer(),
                                Text(
                                  'Total: ${formatCurrency(_calculateTotal())}',
                                  style: AppTextStyles.body2.copyWith(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Print Actions (Prioritized for fast sales)
              Builder(builder: (ctx) {
                final isFuel = (widget.saleData['category'] ?? '').toString().toLowerCase() == 'fuel' || (widget.saleData['category'] ?? '').toString().toLowerCase() == 'petrol' || (widget.saleData['category'] ?? '').toString().toLowerCase() == 'gas';
                final bluetoothButtonLabel = _isCheckoutLockedToReceipt
                    ? 'Print Receipt (Bluetooth)'
                    : (isFuel ? 'Print (58mm)' : 'Print (Bluetooth)');
                return Column(children: [
                  if (isFuel) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(color: Colors.yellow.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.yellow)),
                      child: Row(children: const [Icon(Icons.print, size: 16, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Print a 58mm POS receipt for the customer', style: TextStyle(fontWeight: FontWeight.w600)))]),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Determine whether to show USB print option based on settings or platform
                  Builder(builder: (innerCtx) {
                    if (kIsWeb) {
                      // Web: Single optimized print button using browser dialog
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _printReceiptWeb,
                          icon: const Icon(Icons.print),
                          label: const Text('Print Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            disabledBackgroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      );
                    }
                    // Mobile: Show USB and Bluetooth options
                    return Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _printReceiptUsb,
                          icon: const Icon(Icons.usb),
                          label: const Text('Print (USB)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _printReceipt,
                          icon: const Icon(Icons.print),
                          label: Text(bluetoothButtonLabel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      )
                    ]);
                  }),

                  // PDF preview / print action (similar UX to Receipt Customization preview)
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isPreviewing ? null : _previewPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Preview PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ]);
              }),
              const SizedBox(height: 16),

              if (_hasPharmacyPrescription) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _printPharmacyPrescription,
                    icon: const Icon(Icons.local_pharmacy),
                    label: const Text('Print Prescription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Compact payment breakdown preview
              if ((widget.saleData['paymentBreakdown'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                Builder(builder: (ctx) {
                  final paymentBreakdown = (widget.saleData['paymentBreakdown'] as List<dynamic>?)
                      ?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
                      .toList();
                  final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payments', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Column(
                          children: paymentBreakdown!.map((pb) {
                            final method = (pb['method'] ?? '').toString().toUpperCase();
                            final tx = pb['transactionId'] ?? '';
                            final amt = double.tryParse((pb['amount'] ?? 0.0).toString()) ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('$method${tx != null && tx.toString().isNotEmpty ? ' • ${tx.toString()}' : ''}', style: AppTextStyles.body2)),
                                  Text(currency.format(amt), style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              // PDF actions (Save / Share) - shown when generated
              if (_pdfGenerating) ...[
                Row(children: [Expanded(child: Text('Generating PDF receipt...', style: TextStyle(color: Colors.grey))), const SizedBox(width: 12), const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))]),
                const SizedBox(height: 12),
              ] else if (_pdfFile != null || _pdfBytes != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _savePdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Save PDF'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sharePdf,
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Builder(builder: (_) {
                  final printLabel = widget.invoiceLockedAfterCheckout
                      ? 'Print Receipt (Bluetooth)'
                      : 'Print Invoice (Bluetooth)';
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isPrinting ? null : _printBluetoothInvoice,
                      icon: const Icon(Icons.print_rounded),
                      label: Text(printLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ] else if (!_pdfGenerating && _pdfFile == null && _pdfBytes == null && widget.pdfFuture == null) ...[
                // Offer explicit Generate PDF actions when no background generation was started
                if (widget.invoiceLockedAfterCheckout) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generatePdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Generate PDF Receipt'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isPrinting ? null : _printBluetoothInvoice,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Print Receipt (Bluetooth)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generatePdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Generate PDF Receipt'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generatePdfInvoice,
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Generate PDF Invoice'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _printPdfInvoice,
                          icon: const Icon(Icons.print),
                          label: const Text('Print Invoice'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isPrinting ? null : _printBluetoothInvoice,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Print Invoice (Bluetooth)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],

              if (widget.invoiceLockedAfterCheckout) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'Invoice generation is locked after checkout. You can still print the receipt.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                // Generate Invoice Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isEmailing ? null : _generateInvoice,
                    icon: const Icon(Icons.receipt),
                    label: const Text('Generate Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Other Actions (Email, Share, PDF Generation)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSharing ? null : _shareReceipt,
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isEmailing ? null : _emailReceipt,
                      icon: const Icon(Icons.email),
                      label: const Text('Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    _markSaleCompleted();
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
