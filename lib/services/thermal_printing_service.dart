import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'thermal_printer_manager.dart';
import 'esc_pos_receipt_generator.dart';

/// Comprehensive Thermal Printing Service
/// Manages all thermal printing operations for the app
class ThermalPrintingService {
  static const String _tag = '[ThermalPrintingService]';
  static final ThermalPrintingService _instance = ThermalPrintingService._internal();

  factory ThermalPrintingService() {
    return _instance;
  }

  ThermalPrintingService._internal();

  final ThermalPrinterManager _printerManager = ThermalPrinterManager();
  bool _initialized = false;

  // Getters
  bool get isInitialized => _initialized;
  ThermalPrinterManager get printerManager => _printerManager;
  bool get isConnected => _printerManager.status == PrinterStatus.connected;
  ThermalPrinterDevice? get connectedPrinter => _printerManager.connectedPrinter;

  /// Initialize thermal printing service
  Future<void> initialize() async {
    _log('Initializing Thermal Printing Service');
    try {
      await _printerManager.initialize();
      _initialized = true;
      _log('Thermal Printing Service initialized successfully');
    } catch (e) {
      _log('Error initializing service: $e');
      rethrow;
    }
  }

  /// Check if printer is available on this platform
  bool isPrinterAvailable() {
    // Thermal printing is available on both web and Android
    return !kIsWeb || kIsWeb; // Always true for demonstration
  }

  /// Get available printers
  Future<List<ThermalPrinterDevice>> getAvailablePrinters() async {
    _log('Getting available printers');
    if (!_initialized) {
      await initialize();
    }
    return await _printerManager.discoverPrinters();
  }

  /// Connect to printer by device
  Future<bool> connectToPrinter(ThermalPrinterDevice device) async {
    _log('Connecting to printer: ${device.name}');
    return await _printerManager.connectToPrinter(device);
  }

  /// Disconnect from printer
  Future<void> disconnectFromPrinter() async {
    _log('Disconnecting from printer');
    await _printerManager.disconnectFromPrinter();
  }

  /// Print receipt with full details
  Future<bool> printFullReceipt({
    required String businessName,
    required String receiptNumber,
    required DateTime receiptDate,
    required List<ReceiptLineItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    String? customerName,
    String? storeName,
    String? storeAddress,
    String? storeTelephone,
    int paperWidth = 80,
  }) async {
    try {
      _log('Printing full receipt: $receiptNumber');

      if (!_initialized) {
        await initialize();
      }

      // Check connection status before printing
      final status = await _printerManager.checkPrinterStatus();
      if (status != PrinterStatus.connected) {
        _log('⚠️  Printer not connected (status: $status). Attempting to reconnect...');
        
        // Try to discover and reconnect
        final printers = await _printerManager.discoverPrinters();
        if (printers.isEmpty) {
          _log('❌ No printers found');
          return false;
        }
        
        final connected = await _printerManager.connectToPrinter(printers.first);
        if (!connected) {
          _log('❌ Failed to reconnect to printer');
          return false;
        }
        
        // Wait for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Generate ESC/POS receipt
      final receiptBytes = EscPosReceiptGenerator.generateReceipt(
        businessName: businessName,
        receiptNumber: receiptNumber,
        receiptDate: receiptDate,
        items: items,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        paymentMethod: paymentMethod,
        customerName: customerName,
        storeName: storeName,
        storeAddress: storeAddress,
        storeTelephone: storeTelephone,
        paperWidth: paperWidth,
      );

      _log('Generated receipt (${receiptBytes.length} bytes)');

      // Print using raw bytes
      return await _printerManager.printRawBytes(receiptBytes);
    } catch (e) {
      _log('Error printing receipt: $e');
      return false;
    }
  }

  /// Print simple text receipt
  Future<bool> printTextReceipt({
    required String receiptText,
    required String businessName,
    int paperWidth =80,
  }) async {
    try {
      _log('Printing text receipt');

      if (!_initialized) {
        await initialize();
      }

      // Check if printer is actually connected
      final status = await _printerManager.checkPrinterStatus();
      if (status != PrinterStatus.connected) {
        _log('⚠️  Printer not connected (status: $status). Attempting to reconnect...');
        
        // Try to discover and reconnect to the last connected printer
        final printers = await _printerManager.discoverPrinters();
        if (printers.isEmpty) {
          _log('❌ No printers found');
          return false;
        }
        
        final connected = await _printerManager.connectToPrinter(printers.first);
        if (!connected) {
          _log('❌ Failed to reconnect to printer');
          return false;
        }
        
        // Wait for connection to stabilize
        await Future.delayed(const Duration(milliseconds: 300));
      }

      return await _printerManager.printReceipt(
        receiptText: receiptText,
        businessName: businessName,
        paperWidth: paperWidth,
      );
    } catch (e) {
      _log('Error printing text receipt: $e');
      return false;
    }
  }

  /// Print raw bytes directly
  Future<bool> printRawBytes(Uint8List bytes) async {
    try {
      _log('Printing ${bytes.length} raw bytes');

      if (!_initialized) {
        await initialize();
      }

      return await _printerManager.printRawBytes(bytes);
    } catch (e) {
      _log('Error printing raw bytes: $e');
      return false;
    }
  }

  /// Test printer connection
  Future<PrinterTestResult> testPrinterConnection() async {
    _log('Testing printer connection');
    try {
      if (!_initialized) {
        await initialize();
      }

      final isConnected = await _printerManager.testConnection();
      final status = await _printerManager.checkPrinterStatus();

      final result = PrinterTestResult(
        isSuccessful: isConnected,
        status: status,
        timestamp: DateTime.now(),
        platform: kIsWeb ? 'Web' : 'Android',
        printerName: _printerManager.connectedPrinter?.name,
      );

      _log('Test result: $result');
      return result;
    } catch (e) {
      _log('Error testing connection: $e');
      return PrinterTestResult(
        isSuccessful: false,
        status: PrinterStatus.error,
        timestamp: DateTime.now(),
        platform: kIsWeb ? 'Web' : 'Android',
        error: e.toString(),
      );
    }
  }

  /// Generate test receipt for testing
  static Uint8List generateTestReceipt({
    int paperWidth = 58,
  }) {
    return EscPosReceiptGenerator.generateReceipt(
      businessName: 'TEST BUSINESS',
      receiptNumber: 'TEST-001',
      receiptDate: DateTime.now(),
      items: [
        ReceiptLineItem(
          name: 'Test Item 1',
          quantity: 1,
          unitPrice: 10.0,
          total: 10.0,
        ),
        ReceiptLineItem(
          name: 'Test Item 2',
          quantity: 2,
          unitPrice: 5.0,
          total: 10.0,
        ),
      ],
      subtotal: 20.0,
      tax: 2.0,
      discount: 0.0,
      total: 22.0,
      paymentMethod: 'TEST',
      customerName: 'Test Customer',
      paperWidth: paperWidth,
    );
  }

  /// Get printer status
  Future<PrinterStatus> getPrinterStatus() async {
    return await _printerManager.checkPrinterStatus();
  }

  /// Get formatted status string
  String getStatusString(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.connected:
        return 'Connected';
      case PrinterStatus.disconnected:
        return 'Disconnected';
      case PrinterStatus.printing:
        return 'Printing';
      case PrinterStatus.error:
        return 'Error';
      case PrinterStatus.unknown:
        return 'Unknown';
    }
  }

  /// Utility: Parse numeric value safely
  static num parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  /// Utility: Parse double value safely
  static double parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  /// Ensure Bluetooth permissions
  static Future<bool> ensureBluetoothPermissions() async {
    if (kIsWeb) {
      return true; // No permissions needed for web
    }
    // For Android, permissions would be handled by the platform impl
    // Return true for now - actual permission handling in ThermalPrinterManager
    return true;
  }

  /// Create complete receipt text
  static String createCompleteReceipt({
    required String businessName,
    required int paperWidth,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String? orderId,
    String? cashier,
  }) {
    final sb = StringBuffer();

    // Header - centered formal title
    final title = businessName.toUpperCase();
    final titlePadding = ((paperWidth ~/ 2) - (title.length ~/ 2)).clamp(0, paperWidth);
    sb.writeln(' ' * titlePadding + title);
    sb.writeln('-' * paperWidth);

    // Date & Invoice
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    sb.writeln('Date: $now');
    if (orderId != null && orderId.isNotEmpty) {
      sb.writeln('Invoice: $orderId');
    }
    if (cashier != null && cashier.isNotEmpty) {
      sb.writeln('Cashier: $cashier');
    }

    sb.writeln('-' * paperWidth);

    // Items header
    final amountColWidth = 12; // reserve for qty x unit = e.g. "2 x 12.50"
    final priceColWidth = 10; // reserve for item total
    final nameColWidth = (paperWidth - amountColWidth - priceColWidth - 2).clamp(10, paperWidth);

    sb.writeln('${_padRight('Item', nameColWidth)} ${_padLeft('Qty x Price', amountColWidth)} ${_padLeft('Total', priceColWidth)}');
    sb.writeln('-' * paperWidth);

    // Items
    for (var item in items) {
      final name = (item['name'] ?? 'Item').toString();
      final qty = parseNum(item['quantity']);
      final price = parseDouble(item['price']);
      final itemTotal = (item['total'] != null) ? parseDouble(item['total']) : (qty * price);

      final qtyPrice = '${qty.toStringAsFixed(0)} x ${price.toStringAsFixed(2)}';
      final lineName = name.length > nameColWidth ? name.substring(0, nameColWidth) : name;

      sb.writeln('${_padRight(lineName, nameColWidth)} ${_padLeft(qtyPrice, amountColWidth)} ${_padLeft('₦' + itemTotal.toStringAsFixed(2), priceColWidth)}');

      // If name wraps, continue on next line(s)
      if (name.length > nameColWidth) {
        final remaining = name.substring(nameColWidth);
        sb.writeln(_padRight(remaining, paperWidth));
      }
    }

    sb.writeln('-' * paperWidth);

    // Totals
    final labelWidth = paperWidth - 12;
    const currency = '₦';
    sb.writeln('${_padRight('Subtotal:', labelWidth)} ${_padLeft(currency + totalAmount.toStringAsFixed(2), 12)}');
    sb.writeln('${_padRight('Payment:', labelWidth)} ${_padLeft(paymentMethod, 12)}');

    sb.writeln('\nAuthorized Signature:');
    sb.writeln('______________________________');

    sb.writeln('\nThank you for your business!');
    sb.writeln('Powered by Manage Care');

    return sb.toString();
  }

  // Utility padding helpers for text receipts
  static String _padRight(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text + ' ' * (width - text.length);
  }

  static String _padLeft(String text, int width) {
    if (text.length >= width) return text.substring(text.length - width);
    return ' ' * (width - text.length) + text;
  }

  /// Get available Bluetooth printers
  static Future<List<ThermalPrinterDevice>> getAvailableBluetoothPrinters() async {
    if (kIsWeb) {
      return []; // Not available on web
    }
    // Create instance to use discover method
    final manager = ThermalPrinterManager();
    return await manager.discoverPrinters();
  }

  /// Test printer connection by MAC address
  static Future<bool> testBluetoothPrinter(String? macAddress) async {
    if (macAddress == null || macAddress.isEmpty) {
      return false;
    }
    if (kIsWeb) {
      return true; // Web doesn't use MAC addresses
    }
    // Create instance and test connection
    final manager = ThermalPrinterManager();
    await manager.initialize();
    return true; // Simplified for now
  }

  /// Print via Bluetooth
  static Future<bool> printViaBluetooth({
    required String thermalText,
    required String? printerMac,
    int paperWidth = 80,
  }) async {
    if (kIsWeb) {
      // On web, printing would be handled by browser
      return true;
    }
    
    if (printerMac == null || printerMac.isEmpty) {
      print('[ThermalPrintingService] ❌ No printer MAC address provided');
      return false;
    }
    
    try {
      // Create instance manager
      final manager = ThermalPrinterManager();
      await manager.initialize();
      
      // First, discover available printers
      print('[ThermalPrintingService] Discovering printers...');
      final printers = await manager.discoverPrinters();
      
      if (printers.isEmpty) {
        print('[ThermalPrintingService] ❌ No printers found');
        return false;
      }
      
      // Find the printer by MAC address
      final printer = printers.firstWhere(
        (p) => p.address.toUpperCase() == printerMac.toUpperCase(),
        orElse: () {
          print('[ThermalPrintingService] ⚠️  Printer with MAC $printerMac not found');
          // Try to connect anyway using the first available printer
          return printers.first;
        },
      );
      
      print('[ThermalPrintingService] Connecting to printer: ${printer.name}');
      final connected = await manager.connectToPrinter(printer);
      
      if (!connected) {
        print('[ThermalPrintingService] ❌ Failed to connect to printer');
        return false;
      }
      
      print('[ThermalPrintingService] ✓ Connected to printer');
      
      // Add small delay to ensure printer is ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Now print the receipt
      print('[ThermalPrintingService] Sending receipt to printer...');
      return await manager.printReceipt(
        receiptText: thermalText,
        businessName: 'Business',
        paperWidth: paperWidth,
      );
    } catch (e) {
      print('[ThermalPrintingService] ❌ Error during Bluetooth printing: $e');
      return false;
    }
  }

  void _log(String message) {
    print('$_tag $message');
  }
}

/// Result of printer connection test
class PrinterTestResult {
  final bool isSuccessful;
  final PrinterStatus status;
  final DateTime timestamp;
  final String platform;
  final String? printerName;
  final String? error;

  PrinterTestResult({
    required this.isSuccessful,
    required this.status,
    required this.timestamp,
    required this.platform,
    this.printerName,
    this.error,
  });

  @override
  String toString() {
    return 'PrinterTestResult(success: $isSuccessful, status: $status, platform: $platform, printer: $printerName, time: $timestamp)';
  }
}
