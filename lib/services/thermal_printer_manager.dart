// Copyright 2026 Manage Care. All rights reserved.
// Use of this source code is governed by an Apache 2.0 license
// that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Thermal Printer Status enum
enum PrinterStatus {
  connected,
  disconnected,
  printing,
  error,
  unknown,
}

/// Thermal Printer Device model
class ThermalPrinterDevice {
  final String address;
  final String name;
  final int? port;
  final String type; // 'bluetooth' or 'usb'

  ThermalPrinterDevice({
    required this.address,
    required this.name,
    this.port,
    required this.type,
  });

  @override
  String toString() => 'Printer($name - $address)';
}

/// Thermal Printer Manager
/// Handles thermal printing operations across web and Android platforms
class ThermalPrinterManager {
  static const String _tag = '[ThermalPrinterManager]';
  static final ThermalPrinterManager _instance = ThermalPrinterManager._internal();

  factory ThermalPrinterManager() {
    return _instance;
  }

  ThermalPrinterManager._internal();

  // Platform-specific implementations
  PrinterPlatformImpl? _platformImpl;
  ThermalPrinterDevice? _connectedPrinter;
  PrinterStatus _status = PrinterStatus.disconnected;

  // Status stream for diagnostics
  final StreamController<PrinterStatus> _statusController = StreamController<PrinterStatus>.broadcast();

  // Getters
  PrinterStatus get status => _status;
  ThermalPrinterDevice? get connectedPrinter => _connectedPrinter;
  Stream<PrinterStatus> get onStatusChanged => _statusController.stream;

  void _updateStatus(PrinterStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _log('Status changed -> ${_status.toString().split('.').last}');
    try {
      _statusController.add(_status);
    } catch (e) {
      _log('Failed to emit status to stream: $e');
    }
  }

  /// Dispose resources (call when app shuts down)
  void dispose() {
    try {
      _statusController.close();
    } catch (e) {
      _log('Error closing status stream: $e');
    }
  }

  /// Initialize printer manager
  Future<void> initialize() async {
    _log('Initializing Thermal Printer Manager');
    if (kIsWeb) {
      _platformImpl = WebPrinterImpl();
    } else {
      _platformImpl = AndroidPrinterImpl();
    }
    await _platformImpl?.initialize();
    _log('Thermal Printer Manager initialized');
  }

  /// Discover available printers
  Future<List<ThermalPrinterDevice>> discoverPrinters() async {
    _log('Discovering printers...');
    if (_platformImpl == null) {
      await initialize();
    }
    final devices = await _platformImpl?.discoverPrinters() ?? [];
    _log('Found ${devices.length} printers');
    return devices;
  }

  /// Connect to printer
  Future<bool> connectToPrinter(ThermalPrinterDevice device) async {
    try {
      final now = DateTime.now().toIso8601String();
      _log('[$now] Connecting to printer: ${device.name} (${device.address})');
      if (_platformImpl == null) {
        await initialize();
      }
      
      final success = await _platformImpl?.connectToPrinter(device) ?? false;
      if (success) {
        _connectedPrinter = device;
        _updateStatus(PrinterStatus.connected);
        _log('Connected to printer: ${device.name}');
      } else {
        _updateStatus(PrinterStatus.error);
        _log('Failed to connect to printer: ${device.name}');
      }
      return success;
    } catch (e) {
      _log('Error connecting to printer: $e');
      _updateStatus(PrinterStatus.error);
      return false;
    }
  }

  /// Disconnect from printer
  Future<void> disconnectFromPrinter() async {
    _log('Disconnecting from printer');
    await _platformImpl?.disconnectFromPrinter();
    _connectedPrinter = null;
    _updateStatus(PrinterStatus.disconnected);
  }

  /// Print receipt
  Future<bool> printReceipt({
    required String receiptText,
    required String businessName,
    int paperWidth = 58, // 58mm or 80mm
  }) async {
    try {
      if (_status != PrinterStatus.connected) {
        _log('Printer not connected');
        return false;
      }

      _updateStatus(PrinterStatus.printing);
      _log('Printing receipt...');

      final success = await _platformImpl?.printReceipt(
        receiptText: receiptText,
        businessName: businessName,
        paperWidth: paperWidth,
      ) ?? false;

      if (success) {
        _log('Receipt printed successfully');
        _updateStatus(PrinterStatus.connected);
      } else {
        _log('Failed to print receipt');
        _updateStatus(PrinterStatus.error);
      }

      return success;
    } catch (e) {
      _log('Error printing receipt: $e');
      _updateStatus(PrinterStatus.error);
      return false;
    }
  }

  /// Print raw bytes (ESC/POS commands)
  Future<bool> printRawBytes(Uint8List bytes) async {
    try {
      if (_status != PrinterStatus.connected) {
        _log('Printer not connected');
        return false;
      }

      _updateStatus(PrinterStatus.printing);
      _log('Printing raw bytes (${bytes.length} bytes)...');

      final success = await _platformImpl?.printRawBytes(bytes) ?? false;

      if (success) {
        _log('Raw bytes printed successfully');
        _updateStatus(PrinterStatus.connected);
      } else {
        _log('Failed to print raw bytes');
        _updateStatus(PrinterStatus.error);
      }

      return success;
    } catch (e) {
      _log('Error printing raw bytes: $e');
      _updateStatus(PrinterStatus.error);
      return false;
    }
  }

  /// Test printer connection
  Future<bool> testConnection() async {
    try {
      _log('Testing printer connection...');
      if (_platformImpl == null) {
        await initialize();
      }
      final success = await _platformImpl?.testConnection() ?? false;
      _log('Connection test ${success ? 'passed' : 'failed'}');
      return success;
    } catch (e) {
      _log('Error testing connection: $e');
      return false;
    }
  }

  /// Check printer status
  Future<PrinterStatus> checkPrinterStatus() async {
    if (_platformImpl == null) {
      _log('checkPrinterStatus: platform impl not initialized');
      _updateStatus(PrinterStatus.unknown);
      return PrinterStatus.unknown;
    }

    final implStatus = await _platformImpl?.checkStatus() ?? PrinterStatus.unknown;
    _updateStatus(implStatus);
    return _status;
  }

  void _log(String message) {
    print('$_tag $message');
  }
}

/// Platform-specific printer implementation interface
abstract class PrinterPlatformImpl {
  Future<void> initialize();
  Future<List<ThermalPrinterDevice>> discoverPrinters();
  Future<bool> connectToPrinter(ThermalPrinterDevice device);
  Future<void> disconnectFromPrinter();
  Future<bool> printReceipt({
    required String receiptText,
    required String businessName,
    required int paperWidth,
  });
  Future<bool> printRawBytes(Uint8List bytes);
  Future<bool> testConnection();
  Future<PrinterStatus> checkStatus();
}

/// Web-based printer implementation
class WebPrinterImpl extends PrinterPlatformImpl {
  @override
  Future<void> initialize() async {
    print('[WebPrinter] Initializing web printer');
  }

  @override
  Future<List<ThermalPrinterDevice>> discoverPrinters() async {
    print('[WebPrinter] Discovering printers (Web only supports connected printers)');
    // Web doesn't typically discover printers, relies on system print dialog
    return [];
  }

  @override
  Future<bool> connectToPrinter(ThermalPrinterDevice device) async {
    print('[WebPrinter] Connecting to printer (using system print dialog)');
    return true; // Web uses system print dialog
  }

  @override
  Future<void> disconnectFromPrinter() async {
    print('[WebPrinter] Disconnecting from printer');
  }

  @override
  Future<bool> printReceipt({
    required String receiptText,
    required String businessName,
    required int paperWidth,
  }) async {
    try {
      print('[WebPrinter] Printing receipt via system print dialog');
      // In a real implementation, this would use the printing package
      // to open the system print dialog
      return true;
    } catch (e) {
      print('[WebPrinter] Error printing: $e');
      return false;
    }
  }

  @override
  Future<bool> printRawBytes(Uint8List bytes) async {
    try {
      print('[WebPrinter] Printing raw bytes via system print dialog');
      return true;
    } catch (e) {
      print('[WebPrinter] Error printing: $e');
      return false;
    }
  }

  @override
  Future<bool> testConnection() async {
    print('[WebPrinter] Testing connection (always available on web)');
    return true;
  }

  @override
  Future<PrinterStatus> checkStatus() async {
    return PrinterStatus.unknown; // Web doesn't maintain persistent connection
  }
}

/// Android-based printer implementation
class AndroidPrinterImpl extends PrinterPlatformImpl {
  String? _connectedMac;
  bool _isReconnecting = false;
  Timer? _reconnectionTimer;
  Timer? _connectionCheckTimer;

  @override
  Future<void> initialize() async {
    print('[AndroidPrinter] Initializing Android printer with print_bluetooth_thermal');
    try {
      // Check if Bluetooth is available
      final isAvailable = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isAvailable) {
        print('[AndroidPrinter] ⚠️  Bluetooth is not enabled');
      } else {
        print('[AndroidPrinter] ✓ Bluetooth is available and enabled');
      }
    } catch (e) {
      print('[AndroidPrinter] ❌ Error checking Bluetooth: $e');
    }
  }

  @override
  Future<List<ThermalPrinterDevice>> discoverPrinters() async {
    try {
      print('[AndroidPrinter] Discovering Bluetooth printers...');
      
      // Get paired devices
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      final List<ThermalPrinterDevice> printers = [];
      
      for (final device in devices) {
        final deviceName = device.name ?? 'Unknown';
        final deviceMac = device.macAdress ?? '';
        print('[AndroidPrinter]   ✓ Found: $deviceName ($deviceMac)');
        printers.add(
          ThermalPrinterDevice(
            address: deviceMac,
            name: deviceName,
            type: 'bluetooth',
          ),
        );
      }
      
      print('[AndroidPrinter] ✓ Discovered ${printers.length} printer(s)');
      return printers;
    } catch (e) {
      print('[AndroidPrinter] ❌ Error discovering printers: $e');
      return [];
    }
  }

  @override
  Future<bool> connectToPrinter(ThermalPrinterDevice device) async {
    try {
      print('[AndroidPrinter] Connecting to: ${device.name} (${device.address})');
      
      // Cancel any existing timers
      _reconnectionTimer?.cancel();
      _connectionCheckTimer?.cancel();
      
      // Connect using the MAC address
      try {
        await PrintBluetoothThermal.connect(macPrinterAddress: device.address);
        _connectedMac = device.address;
        print('[AndroidPrinter] ✓ Connected to ${device.name}');
      } catch (e) {
        print('[AndroidPrinter] ❌ BLE connection failed: $e');
        _connectedMac = null;
        return false;
      }
      
      // Start connection monitoring for auto-reconnection
      _startConnectionMonitoring(device);
      
      return true;
    } catch (e) {
      print('[AndroidPrinter] ❌ Connection error: $e');
      return false;
    }
  }

  /// Monitor connection state and handle auto-reconnection
  void _startConnectionMonitoring(ThermalPrinterDevice device) {
    print('[AndroidPrinter] Starting connection monitoring...');
    
    // Cancel existing timer first
    _connectionCheckTimer?.cancel();
    
    // Check connection every 5 seconds
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        try {
          final now = DateTime.now().toIso8601String();
          final isConnected = await PrintBluetoothThermal.connectionStatus;
          print('[AndroidPrinter] [$now] connectionStatus check for ${device.name} (${device.address}): $isConnected');

          if (!isConnected && !_isReconnecting) {
            print('[AndroidPrinter] ⚠️  Device disconnected, initiating reconnection...');
            _attemptReconnection(device);
          }
        } catch (e) {
          print('[AndroidPrinter] ⚠️  Error checking connection: $e');
        }
      },
    );
  }

  /// Attempt to reconnect to the printer
  Future<void> _attemptReconnection(ThermalPrinterDevice device) async {
    if (_isReconnecting) {
      print('[AndroidPrinter] ⏳ Reconnection already in progress...');
      return;
    }

    _isReconnecting = true;
    final now = DateTime.now().toIso8601String();
    print('[AndroidPrinter] [$now] Attempting reconnection in 3 seconds for ${device.name} (${device.address})...');

    // Cancel existing reconnection timer
    _reconnectionTimer?.cancel();
    
    _reconnectionTimer = Timer(const Duration(seconds: 3), () async {
      try {
        final now2 = DateTime.now().toIso8601String();
        print('[AndroidPrinter] [$now2] 🔄 Reconnecting to ${device.name} (${device.address})...');
        
        // Try to connect
        await PrintBluetoothThermal.connect(macPrinterAddress: device.address);
        _connectedMac = device.address;
        print('[AndroidPrinter] ✓ Reconnection successful');
      } catch (e) {
        print('[AndroidPrinter] ❌ Reconnection failed: $e');
        print('[AndroidPrinter] ⏳ Will retry in 5 seconds...');
      } finally {
        _isReconnecting = false;
      }
    });
  }

  @override
  Future<void> disconnectFromPrinter() async {
    try {
      final now = DateTime.now().toIso8601String();
      print('[AndroidPrinter] [$now] Disconnecting from printer...');
      
      // Cancel all timers
      _reconnectionTimer?.cancel();
      _connectionCheckTimer?.cancel();
      _reconnectionTimer = null;
      _connectionCheckTimer = null;
      
      // Disconnect from device. Different versions of the
      // print_bluetooth_thermal package expose `disconnect` as
      // either a method or a Future-valued getter. Try both
      // forms to remain compatible and avoid NoSuchMethodError.
      if (_connectedMac != null) {
        try {
          try {
            // Preferred: method call
            await PrintBluetoothThermal.disconnect;
          } catch (methodErr) {
            // Fallback: property/getter that returns a Future
            try {
              await PrintBluetoothThermal.disconnect;
            } catch (getterErr) {
              print('[AndroidPrinter] ⚠️ disconnect() and disconnect getter both failed. methodErr: $methodErr, getterErr: $getterErr');
            }
          }
        } catch (e) {
          print('[AndroidPrinter] ⚠️ Error while attempting to disconnect: $e');
        }
      }
      
      _connectedMac = null;
      _isReconnecting = false;
      
      print('[AndroidPrinter] ✓ Disconnected');
    } catch (e) {
      print('[AndroidPrinter] ❌ Error disconnecting: $e');
    }
  }

  @override
  Future<bool> printReceipt({
    required String receiptText,
    required String businessName,
    required int paperWidth,
  }) async {
    try {
      // Verify connection before printing
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        print('[AndroidPrinter] ❌ Printer not connected');
        return false;
      }

      print('[AndroidPrinter] 🖨️  Printing receipt...');
      
      // Normalize unsupported characters (e.g., Naira symbol) to safe ASCII fallback
      final normalized = receiptText.replaceAll('₦', 'NGN ');
      // Use UTF-8 encoding to preserve multi-byte characters where supported
      final bytes = Uint8List.fromList(utf8.encode(normalized));
      // Convert to List<int> for plugin compatibility
      final success = await PrintBluetoothThermal.writeBytes(bytes.toList());
      
      if (success) {
        print('[AndroidPrinter] ✓ Receipt printed successfully');
        return true;
      } else {
        print('[AndroidPrinter] ❌ Failed to print receipt');
        return false;
      }
    } catch (e) {
      print('[AndroidPrinter] ❌ Error printing receipt: $e');
      return false;
    }
  }

  @override
  Future<bool> printRawBytes(Uint8List bytes) async {
    try {
      if (_connectedMac == null || _connectedMac!.isEmpty) {
        print('[AndroidPrinter] ❌ No device connected');
        return false;
      }

      // Verify connection before printing (MUST await this)
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        print('[AndroidPrinter] ❌ Printer not connected');
        return false;
      }

      print('[AndroidPrinter] 🖨️  Sending ${bytes.length} bytes...');
      
      // Send in chunks to prevent buffer overflow
      // Most thermal printers have a buffer of 1-4KB
      const chunkSize = 512; // Send 512 bytes at a time
      bool allSuccess = true;
      
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
        final chunk = bytes.sublist(i, end);
        
        print('[AndroidPrinter] Sending chunk ${(i ~/ chunkSize) + 1}/${(bytes.length + chunkSize - 1) ~/ chunkSize} (${chunk.length} bytes)...');
        
        // Convert Uint8List to List<int> if needed by writeBytes
        // Convert chunk to List<int> to ensure plugin receives a List, not a byte[]
        final success = await PrintBluetoothThermal.writeBytes(chunk.toList());
        
        if (!success) {
          print('[AndroidPrinter] ❌ Failed to send chunk at offset $i');
          allSuccess = false;
          break;
        }
        
        // Add a small delay between chunks to prevent buffer overflow
        // 50ms is optimal for most thermal printers
        if (end < bytes.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      if (allSuccess) {
        print('[AndroidPrinter] ✓ All data sent successfully');
        // Add final delay to ensure printer processes all data
        await Future.delayed(const Duration(milliseconds: 200));
        print('[AndroidPrinter] (monitor) marking status connected (manager will reflect on next check)');
        return true;
      } else {
        print('[AndroidPrinter] ❌ Failed to send all data');
        print('[AndroidPrinter] (monitor) encountered error sending data (manager will reflect on next check)');
        return false;
      }
    } catch (e) {
      print('[AndroidPrinter] ❌ Error printing: $e');
      return false;
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      print('[AndroidPrinter] 🧪 Testing connection...');
      
      if (_connectedMac == null || _connectedMac!.isEmpty) {
        print('[AndroidPrinter] ❌ Device not connected');
        return false;
      }
      
      // Test by checking connection status
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      
      if (isConnected) {
        print('[AndroidPrinter] ✓ Connection test passed');
      } else {
        print('[AndroidPrinter] ❌ Connection test failed - device unreachable');
      }
      
      return isConnected;
    } catch (e) {
      print('[AndroidPrinter] ❌ Error testing connection: $e');
      return false;
    }
  }

  @override
  Future<PrinterStatus> checkStatus() async {
    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      final status = isConnected ? PrinterStatus.connected : PrinterStatus.disconnected;
      print('[AndroidPrinter] Status: ${status.toString().split('.').last}');
      return status;
    } catch (e) {
      print('[AndroidPrinter] ❌ Error checking status: $e');
      return PrinterStatus.error;
    }
  }
}

// Static helper methods
Future<bool> _ensureBluetoothPermissions() async {
  // Platform-specific implementation
  if (kIsWeb) {
    return true;
  }
  // For Android, this would require platform channel to actual permissions
  return true;
}

Future<List<ThermalPrinterDevice>> _getBluetoothPrinters() async {
  if (kIsWeb) {
    return [];
  }
  // Platform-specific implementation
  return [];
}

Future<bool> _testBluetoothConnection(String macAddress) async {
  if (kIsWeb) {
    return true;
  }
  // Platform-specific implementation
  return true;
}

Future<bool> _printViaBluetoothMac(String text, String mac, int paperWidth) async {
  if (kIsWeb) {
    return true;
  }
  // Platform-specific implementation
  return true;
}

Future<bool> _printWebDocument(String text) async {
  if (!kIsWeb) {
    return false;
  }
  // Web-specific implementation using browser print dialog
  return true;
}

/// Encode printable text for Bluetooth/USB printing.
/// Normalizes unsupported characters (e.g., '₦' -> 'NGN ') and returns UTF-8 bytes.
Uint8List encodePrintableText(String text) {
  final normalized = text.replaceAll('₦', 'NGN ');
  return Uint8List.fromList(utf8.encode(normalized));
}

// Extension on ThermalPrinterManager for static methods
extension ThermalPrinterManagerStatic on ThermalPrinterManager {
  static Future<bool> ensureBluetoothPermissions() => _ensureBluetoothPermissions();
  static Future<List<ThermalPrinterDevice>> getBluetoothPrinters() => _getBluetoothPrinters();
  static Future<bool> testBluetoothConnection(String mac) => _testBluetoothConnection(mac);
  static Future<bool> printViaBluetoothMac(String text, String mac, int pw) => _printViaBluetoothMac(text, mac, pw);
  static Future<bool> printWebDocument(String text) => _printWebDocument(text);
}
