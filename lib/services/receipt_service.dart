import 'thermal_printing_service.dart';

/// Receipt generation service
/// Handles all receipt formatting and printing logic
class ReceiptService {
  static final ReceiptService _instance = ReceiptService._internal();

  factory ReceiptService() => _instance;
  ReceiptService._internal();

  /// Generate and print a receipt
  Future<bool> printReceipt({
    required Map<String, dynamic> saleData,
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    String? taxId,
    String? website,
    String? footerMessage,
    int paperWidth = 80,
    bool includeQRCode = false,
    String? qrData,
    String? printerAddress,
    String? printerIP,
  }) async {
    try {
      // Extract and validate receipt data
      final orderId = saleData['id'] ?? saleData['orderId'] ?? 'N/A';
      // Ensure date is available if needed for future enhancement
      final _ = saleData['date'] is DateTime
          ? saleData['date']
          : DateTime.tryParse(saleData['date'].toString()) ?? DateTime.now();

      // Handle items
      final List<Map<String, dynamic>> items = [];
      if (saleData['items'] is List) {
        items.addAll((saleData['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      } else if (saleData['products'] is List) {
        items.addAll((saleData['products'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      }

      // Calculate totals
      double subtotal = 0;
      for (var item in items) {
        final qty = ThermalPrintingService.parseDouble(item['quantity'] ?? 1);
        final price = ThermalPrintingService.parseDouble(item['price'] ?? 0);
        subtotal += qty * price;
      }

      final tax = ThermalPrintingService.parseDouble(saleData['tax'] ?? 0);
      final discount = ThermalPrintingService.parseDouble(saleData['discount'] ?? 0);
      final total = subtotal + tax - discount;
      final paymentMethod = saleData['paymentMethod'] ?? 'Cash';

      // Use simple receipt text instead of bytes
      final cashier = saleData['cashier'] ?? saleData['createdBy'] ?? 'Cashier';
      final receiptText = ThermalPrintingService.createCompleteReceipt(
        businessName: businessName,
        paperWidth: 58,
        items: items.cast<Map<String, dynamic>>(),
        totalAmount: total,
        paymentMethod: paymentMethod,
        orderId: orderId,
        cashier: cashier,
      );

      // Print to appropriate device
      if (printerAddress != null && printerAddress.isNotEmpty) {
        return await ThermalPrintingService.printViaBluetooth(
          thermalText: receiptText,
          printerMac: printerAddress,
        );
      } else if (printerIP != null && printerIP.isNotEmpty) {
        // Network printing fallback to Bluetooth
        return await ThermalPrintingService.printViaBluetooth(
          thermalText: receiptText,
          printerMac: printerAddress,
        );
      } else {
        // Default: Print directly to connected printer
        final thermalService = ThermalPrintingService();
        return await thermalService.printTextReceipt(
          receiptText: receiptText,
          businessName: businessName,
        );
      }
    } catch (e) {
      print('[ReceiptService] Print error: $e');
      return false;
    }
  }

  /// Get receipt preview as formatted text
  String getReceiptPreview({
    required Map<String, dynamic> saleData,
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    String? taxId,
    String? website,
    String? footerMessage,
  }) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('═' * 32);
    buffer.writeln(businessName);
    buffer.writeln(businessAddress);
    buffer.writeln('Tel: $businessPhone');
    if (taxId != null && taxId.isNotEmpty) {
      buffer.writeln('Tax ID: $taxId');
    }
    if (website != null && website.isNotEmpty) {
      buffer.writeln(website);
    }
    buffer.writeln('═' * 32);

    // Receipt info
    buffer.writeln('Receipt: ${saleData['id'] ?? 'N/A'}');
    buffer.writeln('Date: ${saleData['date'] ?? DateTime.now()}');
    buffer.writeln();

    // Items
    buffer.writeln('─' * 32);
    if (saleData['items'] is List) {
      for (var item in saleData['items'] as List) {
        final name = item['name'] ?? 'Unknown';
        final qty = ThermalPrintingService.parseNum(item['quantity'] ?? 0);
        final price = ThermalPrintingService.parseDouble(item['price'] ?? 0.0);
        final total = qty * price;

        buffer.writeln(name);
        buffer.writeln('  Qty: $qty x \$${price.toStringAsFixed(2)} = \$${total.toStringAsFixed(2)}');
      }
    }
    buffer.writeln('─' * 32);

    // Totals
    final subtotal = ThermalPrintingService.parseDouble(saleData['subtotal'] ?? 0.0);
    final tax = ThermalPrintingService.parseDouble(saleData['tax'] ?? 0.0);
    final discount = ThermalPrintingService.parseDouble(saleData['discount'] ?? 0.0);
    final total = subtotal + tax - discount;

    buffer.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
    if (tax > 0) {
      buffer.writeln('Tax: \$${tax.toStringAsFixed(2)}');
    }
    if (discount > 0) {
      buffer.writeln('Discount: \$${discount.toStringAsFixed(2)}');
    }
    buffer.writeln('TOTAL: \$${total.toStringAsFixed(2)}');
    buffer.writeln();

    // Payment
    buffer.writeln('Payment: ${saleData['paymentMethod'] ?? 'Cash'}');
    buffer.writeln('═' * 32);

    // Footer
    if (footerMessage != null && footerMessage.isNotEmpty) {
      buffer.writeln(
        footerMessage.padLeft((footerMessage.length + 16) ~/ 2).padRight(32)
      );
    }

    return buffer.toString();
  }
  /// Validate receipt data
  bool validateReceiptData(Map<String, dynamic> saleData) {
    return saleData.containsKey('items') &&
        saleData['items'] is List &&
        (saleData['items'] as List).isNotEmpty;
  }

  /// Dispose resources
  void dispose() {
    // ThermalPrintingService is a singleton, no disposal needed
  }
}
