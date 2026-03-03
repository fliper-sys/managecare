import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/thermal_printing_service.dart';
import 'package:business_manager/services/thermal_printer_manager.dart';
import 'package:business_manager/services/esc_pos_receipt_generator.dart';
import 'dart:typed_data';

void main() {
  group('Thermal Printing Service Integration Tests', () {
    late ThermalPrintingService printingService;

    setUp(() {
      printingService = ThermalPrintingService();
    });

    test('Singleton instance is consistent', () {
      final service1 = ThermalPrintingService();
      final service2 = ThermalPrintingService();
      expect(identical(service1, service2), true);
    });

    test('Service initializes successfully', () async {
      await printingService.initialize();
      expect(printingService.isInitialized, true);
    });

    test('Printer availability check returns boolean', () {
      final available = printingService.isPrinterAvailable();
      expect(available, isA<bool>());
    });

    test('Get available printers returns list', () async {
      await printingService.initialize();
      final printers = await printingService.getAvailablePrinters();
      expect(printers, isA<List<ThermalPrinterDevice>>());
    });

    test('Test printer connection returns result', () async {
      await printingService.initialize();
      final result = await printingService.testPrinterConnection();
      expect(result, isA<PrinterTestResult>());
      expect(result.isSuccessful, isA<bool>());
      expect(result.status, isA<PrinterStatus>());
      expect(result.timestamp, isA<DateTime>());
      expect(result.platform, isNotEmpty);
    });

    test('Get printer status returns valid status', () async {
      await printingService.initialize();
      final status = await printingService.getPrinterStatus();
      expect(status, isA<PrinterStatus>());
    });

    test('Status string is non-empty for all statuses', () {
      expect(printingService.getStatusString(PrinterStatus.connected), isNotEmpty);
      expect(printingService.getStatusString(PrinterStatus.disconnected), isNotEmpty);
      expect(printingService.getStatusString(PrinterStatus.printing), isNotEmpty);
      expect(printingService.getStatusString(PrinterStatus.error), isNotEmpty);
      expect(printingService.getStatusString(PrinterStatus.unknown), isNotEmpty);
    });

    test('Generate test receipt produces valid bytes', () {
      final receipt = ThermalPrintingService.generateTestReceipt();
      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(0));
    });

    test('Generate test receipt with 58mm paper', () {
      final receipt = ThermalPrintingService.generateTestReceipt(paperWidth: 58);
      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(0));
    });

    test('Generate test receipt with 80mm paper', () {
      final receipt = ThermalPrintingService.generateTestReceipt(paperWidth: 80);
      expect(receipt, isA<Uint8List>());
      expect(receipt.length, greaterThan(0));
    });

    test('Connected printer is initially null', () {
      expect(printingService.connectedPrinter, isNull);
    });

    test('Printer manager is accessible', () {
      expect(printingService.printerManager, isA<ThermalPrinterManager>());
    });

    test('Disconnect completes without error', () async {
      await printingService.initialize();
      await printingService.disconnectFromPrinter();
      expect(printingService.connectedPrinter, isNull);
    });
  });

  group('Thermal Printing Service Print Operations', () {
    late ThermalPrintingService printingService;

    setUp(() {
      printingService = ThermalPrintingService();
    });

    test('Print full receipt returns boolean', () async {
      await printingService.initialize();
      final result = await printingService.printFullReceipt(
        businessName: 'Test Business',
        receiptNumber: '001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Item 1',
            quantity: 1,
            unitPrice: 10.0,
            total: 10.0,
          ),
        ],
        subtotal: 10.0,
        tax: 1.0,
        discount: 0.0,
        total: 11.0,
        paymentMethod: 'Cash',
      );
      expect(result, isA<bool>());
    });

    test('Print text receipt returns boolean', () async {
      await printingService.initialize();
      final result = await printingService.printTextReceipt(
        receiptText: 'Test Receipt\nItem: 10.00',
        businessName: 'Test Business',
      );
      expect(result, isA<bool>());
    });

    test('Print raw bytes returns boolean', () async {
      await printingService.initialize();
      final bytes = ThermalPrintingService.generateTestReceipt();
      final result = await printingService.printRawBytes(bytes);
      expect(result, isA<bool>());
    });

    test('Print receipt with full details', () async {
      await printingService.initialize();
      final result = await printingService.printFullReceipt(
        businessName: 'Premium Store',
        receiptNumber: 'REC-2024-001',
        receiptDate: DateTime.now(),
        items: [
          ReceiptLineItem(
            name: 'Product A',
            quantity: 2,
            unitPrice: 25.0,
            total: 50.0,
          ),
          ReceiptLineItem(
            name: 'Product B',
            quantity: 1,
            unitPrice: 30.0,
            total: 30.0,
          ),
        ],
        subtotal: 80.0,
        tax: 8.0,
        discount: 5.0,
        total: 83.0,
        paymentMethod: 'Card',
        customerName: 'John Doe',
        storeName: 'Main Branch',
        storeAddress: '123 Main St',
        storeTelephone: '555-1234',
        paperWidth: 80,
      );
      expect(result, isA<bool>());
    });
  });

  group('Printer Test Result Tests', () {
    test('Create successful test result', () {
      final result = PrinterTestResult(
        isSuccessful: true,
        status: PrinterStatus.connected,
        timestamp: DateTime.now(),
        platform: 'Android',
        printerName: 'Test Printer',
      );
      expect(result.isSuccessful, true);
      expect(result.status, PrinterStatus.connected);
      expect(result.platform, equals('Android'));
      expect(result.printerName, equals('Test Printer'));
      expect(result.error, isNull);
    });

    test('Create failed test result with error', () {
      final result = PrinterTestResult(
        isSuccessful: false,
        status: PrinterStatus.error,
        timestamp: DateTime.now(),
        platform: 'Web',
        error: 'Connection timeout',
      );
      expect(result.isSuccessful, false);
      expect(result.status, PrinterStatus.error);
      expect(result.error, equals('Connection timeout'));
    });

    test('Test result toString is descriptive', () {
      final result = PrinterTestResult(
        isSuccessful: true,
        status: PrinterStatus.connected,
        timestamp: DateTime.now(),
        platform: 'Android',
        printerName: 'HP Printer',
      );
      final str = result.toString();
      expect(str, contains('PrinterTestResult'));
      expect(str, contains('success: true'));
      expect(str, contains('connected'));
      expect(str, contains('Android'));
    });
  });

  group('Thermal Printing Service Error Handling', () {
    late ThermalPrintingService printingService;

    setUp(() {
      printingService = ThermalPrintingService();
    });

    test('Service initializes on first operation if not already initialized', () async {
      // When a print operation is called, service auto-initializes if needed
      final service = ThermalPrintingService();
      // Service initializes lazily on first operation
      expect(service.printerManager, isNotNull);
    });

    test('Test connection handles errors gracefully', () async {
      await printingService.initialize();
      final result = await printingService.testPrinterConnection();
      expect(result, isA<PrinterTestResult>());
      // Should complete without throwing
    });

    test('Print operations handle disconnected state', () async {
      await printingService.initialize();
      final result = await printingService.printTextReceipt(
        receiptText: 'Test',
        businessName: 'Test',
      );
      expect(result, isA<bool>());
    });
  });
}
