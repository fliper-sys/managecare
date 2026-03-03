import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/thermal_printer_manager.dart';

void main() {
  group('Thermal Printer Manager Tests', () {
    late ThermalPrinterManager printerManager;

    setUp(() {
      printerManager = ThermalPrinterManager();
    });

    test('Singleton instance returns same object', () {
      final instance1 = ThermalPrinterManager();
      final instance2 = ThermalPrinterManager();
      expect(identical(instance1, instance2), true);
    });

    test('Initial status is disconnected', () {
      expect(printerManager.status, PrinterStatus.disconnected);
    });

    test('Connected printer is initially null', () {
      expect(printerManager.connectedPrinter, isNull);
    });

    test('Initialize printer manager', () async {
      await printerManager.initialize();
      expect(printerManager.status, isNotNull);
    });

    test('Test printer connection', () async {
      await printerManager.initialize();
      final result = await printerManager.testConnection();
      expect(result, isA<bool>());
    });

    test('Check printer status after initialization', () async {
      await printerManager.initialize();
      final status = await printerManager.checkPrinterStatus();
      expect(status, isA<PrinterStatus>());
    });

    test('Discover printers', () async {
      await printerManager.initialize();
      final devices = await printerManager.discoverPrinters();
      expect(devices, isA<List<ThermalPrinterDevice>>());
    });

    test('Printer device has required properties', () {
      final device = ThermalPrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Test Printer',
        type: 'bluetooth',
      );
      expect(device.address, equals('00:11:22:33:44:55'));
      expect(device.name, equals('Test Printer'));
      expect(device.type, equals('bluetooth'));
      expect(device.toString(), contains('Test Printer'));
    });

    test('Disconnect from printer', () async {
      await printerManager.initialize();
      await printerManager.disconnectFromPrinter();
      expect(printerManager.connectedPrinter, isNull);
      expect(printerManager.status, equals(PrinterStatus.disconnected));
    });
  });

  group('Printer Status Tests', () {
    test('All PrinterStatus values are defined', () {
      expect(PrinterStatus.connected, isNotNull);
      expect(PrinterStatus.disconnected, isNotNull);
      expect(PrinterStatus.printing, isNotNull);
      expect(PrinterStatus.error, isNotNull);
      expect(PrinterStatus.unknown, isNotNull);
    });

    test('PrinterStatus enum has correct values', () {
      final statuses = [
        PrinterStatus.connected,
        PrinterStatus.disconnected,
        PrinterStatus.printing,
        PrinterStatus.error,
        PrinterStatus.unknown,
      ];
      expect(statuses.length, equals(5));
    });
  });

  group('Printer Device Tests', () {
    test('Create printer device with all properties', () {
      final device = ThermalPrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'HP Thermal Printer',
        port: 9100,
        type: 'usb',
      );
      expect(device.address, equals('00:11:22:33:44:55'));
      expect(device.name, equals('HP Thermal Printer'));
      expect(device.port, equals(9100));
      expect(device.type, equals('usb'));
    });

    test('Create printer device without port', () {
      final device = ThermalPrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Bluetooth Printer',
        type: 'bluetooth',
      );
      expect(device.port, isNull);
    });

    test('Printer device toString is descriptive', () {
      final device = ThermalPrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Test Printer',
        type: 'bluetooth',
      );
      expect(device.toString(), contains('Printer'));
      expect(device.toString(), contains('Test Printer'));
      expect(device.toString(), contains('00:11:22:33:44:55'));
    });
  });

  group('Platform Implementation Tests', () {
    test('Web printer implementation exists', () {
      final webPrinter = WebPrinterImpl();
      expect(webPrinter, isA<PrinterPlatformImpl>());
    });

    test('Android printer implementation exists', () {
      final androidPrinter = AndroidPrinterImpl();
      expect(androidPrinter, isA<PrinterPlatformImpl>());
    });

    test('Web printer initialize completes', () async {
      final webPrinter = WebPrinterImpl();
      await webPrinter.initialize();
      // Should complete without error
    });

    test('Android printer initialize completes', () async {
      final androidPrinter = AndroidPrinterImpl();
      await androidPrinter.initialize();
      // Should complete without error
    });

    test('Web printer discover returns empty list', () async {
      final webPrinter = WebPrinterImpl();
      final devices = await webPrinter.discoverPrinters();
      expect(devices, isA<List<ThermalPrinterDevice>>());
    });

    test('Android printer discover returns list', () async {
      final androidPrinter = AndroidPrinterImpl();
      final devices = await androidPrinter.discoverPrinters();
      expect(devices, isA<List<ThermalPrinterDevice>>());
    });

    test('Web printer test connection returns true', () async {
      final webPrinter = WebPrinterImpl();
      final result = await webPrinter.testConnection();
      expect(result, equals(true));
    });

    test('Android printer test connection returns bool', () async {
      final androidPrinter = AndroidPrinterImpl();
      final result = await androidPrinter.testConnection();
      expect(result, isA<bool>());
    });
  });
}
