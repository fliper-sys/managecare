import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/receipt_utility.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/receipt_settings_provider.dart';
import '../../services/thermal_printing_service.dart';
import '../../services/esc_pos_receipt_generator.dart';
import '../../services/pdf_receipt_generator.dart';
import '../../services/thermal_printer_manager.dart';
import '../settings/screens/pdf_preview_page.dart';
import '../../services/web_download.dart' as web_download;
import '../../services/email_service.dart';
import '../../services/analytics_service.dart';
import '../../core/access_control.dart';

class PrintingActionSheet extends StatefulWidget {
  final String receiptText;
  final String businessName;
  final String? orderId;
  final String? customerEmail;
  final Map<String, dynamic> saleData;
  final Future<dynamic>? pdfFuture; // File on mobile, Uint8List bytes on web

  const PrintingActionSheet({
    required this.receiptText,
    required this.businessName,
    required this.orderId,
    this.customerEmail,
    required this.saleData,
    this.pdfFuture,
    super.key,
  });

  @override
  State<PrintingActionSheet> createState() => _PrintingActionSheetState();
}

class _PrintingActionSheetState extends State<PrintingActionSheet> {
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
        } else if (first is String && first.trim().isNotEmpty) return _normalizePayment(first);
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

  @override
  void initState() {
    super.initState();
    debugPrint('[PrintingActionSheet] Initialized with orderId: ${widget.orderId}');

    // Listen for background PDF generation if provided
    if (widget.pdfFuture != null) {
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

          return {
            'name': name,
            'quantity': quantity,
            'price': price,
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
        debugPrint('[PrintingActionSheet] Failed to fetch sale doc: $e');
      }

      final _customFooter = settings?.footerMessage;
      final footerWithPowered = (_customFooter?.isNotEmpty == true) ? '$_customFooter\nPowered by Manage Care' : 'Powered by Manage Care';

      // Generate
      if (kIsWeb) {
        final bytes = await PdfReceiptGenerator.generateReceiptPdfBytes(
          businessName: widget.businessName,
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
          poweredByText: footerWithPowered,
          showQrCode: settings?.showQrCode ?? false,
          receiptUrlBase: settings?.receiptUrlBase,
          discount: (widget.saleData['discount'] ?? 0.0).toDouble(),
          businessLogoUrl: business?.logoUrl,
          businessAddress: business?.address,
          businessPhone: business?.phone,
          businessEmail: business?.email,
          subscriptionTier: business?.subscriptionTier,
          businessClass: business?.businessClass,
        );

        setState(() {
          _pdfBytes = bytes;
          _pdfGenerating = false;
          _statusMessage = 'PDF ready (click Save/Share)';
          _statusColor = Colors.green;
        });
      } else {
        final file = await PdfReceiptGenerator.generateReceiptPdf(
          businessName: widget.businessName,
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
          poweredByText: footerWithPowered,
          showQrCode: settings?.showQrCode ?? false,
          receiptUrlBase: settings?.receiptUrlBase,
          discount: (widget.saleData['discount'] ?? 0.0).toDouble(),
          businessLogoUrl: business?.logoUrl,
          businessAddress: business?.address,
          businessPhone: business?.phone,
          businessEmail: business?.email,
          subscriptionTier: business?.subscriptionTier,
          businessClass: business?.businessClass,
        );

        setState(() {
          _pdfFile = file;
          _pdfGenerating = false;
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

          return {
            'name': name,
            'quantity': quantity,
            'price': price,
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
        businessLogoUrl: business?.logoUrl,
        businessAddress: business?.address,
        businessPhone: business?.phone,
        businessEmail: business?.email,
        subscriptionTier: business?.subscriptionTier,
        businessClass: business?.businessClass,
      );

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
      final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
      final business = businessProvider.currentBusiness;
      final isValid = AccessControl.canUseEmailAndPrint(context);

      if (!isValid) {
        setState(() {
          _statusMessage = 'Email receipts require an active Professional subscription';
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
            'name': e['name'] ?? e['productName'] ?? 'Item',
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
          if (e['name'] != null && e['name'].toString().trim().isNotEmpty) {
            name = e['name'].toString();
          } else if (e['product'] is Map && e['product']['name'] != null) {
            name = e['product']['name'].toString();
          } else if (e['productName'] != null) {
            name = e['productName'].toString();
          }

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
          final unitRaw = (e['unit'] ?? e['unitName'] ?? e['uom'] ?? 
              ((e['product'] is Map) ? (e['product']['unit'] ?? e['product']['unitName'] ?? e['product']['uom']) : null) ?? '').toString();

          itemsList.add(
            ReceiptLineItem(
              name: name,
              quantity: quantity,
              unitPrice: price,
              total: lineTotal,
              unit: unitRaw.isNotEmpty ? unitRaw : null,
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
        String? copyLabel;
        if (copies >= 2) {
          if (i == 0) copyLabel = 'CUSTOMER COPY';
          else if (i == 1) copyLabel = 'BUSINESS COPY';
          else copyLabel = 'COPY ${i + 1}';
        }

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
          cashier: cashierName,
          storeName: widget.businessName,
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

  Future<void> _savePdf() async {
    if (_pdfFile == null && _pdfBytes == null) return;
    try {
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

      if (fileToShare != null) {
        await Share.shareXFiles([XFile(fileToShare.path)], text: 'Receipt from ${widget.businessName}');
        setState(() { _statusMessage = 'PDF shared'; _statusColor = Colors.green; });
      } else {
        setState(() { _statusMessage = 'No PDF available to share'; _statusColor = Colors.red; });
      }
    } catch (e) {
      setState(() { _statusMessage = 'Error sharing PDF: $e'; _statusColor = Colors.red; });
    }
  }

  Future<void> _printReceiptWeb() async {
    // Web printing implementation
    setState(() => _isPrinting = true);
    try {
      // Web-specific printing logic
      setState(() {
        _statusMessage = 'Printing on web...';
        _statusColor = Colors.grey;
      });
      // Implement web printing
    } catch (e) {
      setState(() {
        _statusMessage = 'Print failed: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _printReceiptUsb() async {
    // USB printing implementation
    setState(() => _isPrinting = true);
    try {
      // USB printing logic
      setState(() {
        _statusMessage = 'Printing via USB...';
        _statusColor = Colors.grey;
      });
      // Implement USB printing
    } catch (e) {
      setState(() {
        _statusMessage = 'USB print failed: $e';
        _statusColor = Colors.red;
      });
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleBluetoothPrintBytes(List<Uint8List> receipts, int paperWidth) async {
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
          _statusMessage = 'Printer not connected. Please check connection.';
          _statusColor = Colors.orange;
        });
        return;
      }

      // Print each receipt
      for (var i = 0; i < receipts.length; i++) {
        setState(() => _statusMessage = 'Printing receipt ${i + 1}/${receipts.length}...');
        await thermalService.printRawBytes(receipts[i]);
        if (i < receipts.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500)); // Delay between copies
        }
      }

      setState(() {
        _statusMessage = 'Receipt printed successfully!';
        _statusColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Print error: ${e.toString().split('\n').first}';
        _statusColor = Colors.red;
      });
    }
  }

  Future<bool> _attachPdfToEmailIfAvailable(EmailService emailService, String recipient, Map<String, dynamic> emailData) async {
    // Implementation for attaching PDF to email
    return false; // Placeholder
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[PrintingActionSheet] Building UI for orderId: ${widget.orderId}');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  const Text('Printing Actions', style: AppTextStyles.heading5),
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
              ] else if (!_pdfGenerating && _pdfFile == null && _pdfBytes == null && widget.pdfFuture == null) ...[
                // Offer explicit Generate PDF action when no background generation was started
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generatePdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Generate PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                ),
                const SizedBox(height: 12),
              ],

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
              Builder(builder: (ctx) {
                final isFuel = (widget.saleData['category'] ?? '').toString().toLowerCase() == 'fuel' || (widget.saleData['category'] ?? '').toString().toLowerCase() == 'petrol' || (widget.saleData['category'] ?? '').toString().toLowerCase() == 'gas';
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
                          label: Text(isFuel ? 'Print (58mm)' : 'Print (Bluetooth)'),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
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
