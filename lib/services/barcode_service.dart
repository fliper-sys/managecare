import 'package:mobile_scanner/mobile_scanner.dart' as mobile_scanner;
import 'package:barcode_widget/barcode_widget.dart' as barcode_widget;
import 'package:flutter/material.dart';

/// Barcode scanning and generation service
class BarcodeService {
  static final BarcodeService _instance = BarcodeService._internal();
  late mobile_scanner.MobileScannerController _scannerController;

  factory BarcodeService() {
    return _instance;
  }

  BarcodeService._internal();

  /// Initialize barcode scanner
  Future<void> initializeScanner() async {
    _scannerController = mobile_scanner.MobileScannerController(
      detectionSpeed: mobile_scanner.DetectionSpeed.noDuplicates,
      facing: mobile_scanner.CameraFacing.back,
      torchEnabled: false,
    );
  }

  /// Get scanner controller for UI
  mobile_scanner.MobileScannerController get scannerController =>
      _scannerController;

  /// Scan barcode using mobile scanner
  Future<String?> scanBarcode(BuildContext context) async {
    String? scannedCode;

    // Ensure scanner is initialized before showing UI
    try {
      await initializeScanner();
    } catch (e) {
      debugPrint('[BarcodeService] Scanner initialization failed: $e');
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan Barcode'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: mobile_scanner.MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<mobile_scanner.Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  scannedCode = barcode.rawValue!;
                  Navigator.pop(context);
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    return scannedCode;
  }

  /// Validate barcode format
  Future<bool> validateBarcode(String barcode) async {
    // Basic validation: check if barcode is not empty and reasonable length
    if (barcode.isEmpty) return false;

    // EAN-13: 13 digits, EAN-8: 8 digits, UPC-A: 12 digits
    final isValidLength =
        barcode.length == 8 || barcode.length == 12 || barcode.length == 13;

    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(barcode);

    return isValidLength && isNumeric;
  }

  /// Generate barcode string for product (creates unique barcode)
  String generateBarcode(String productId) {
    // Format: prefix + productId padded to create valid EAN-13 format
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final combined = (productId + timestamp).replaceAll(RegExp(r'[^0-9]'), '');

    // Pad or truncate to 13 digits for EAN-13
    String barcode = combined.padRight(13, '0').substring(0, 13);
    return barcode;
  }

  /// Get barcode widget for displaying barcode
  Widget getBarcodeWidget({
    required String value,
    String barcodeType = 'code128',
    double width = 200,
    double height = 100,
  }) {
    return barcode_widget.BarcodeWidget(
      barcode: barcode_widget.Barcode.code128(),
      data: value,
      width: width,
      height: height,
      drawText: true,
    );
  }

  /// Dispose scanner resources
  Future<void> dispose() async {
    await _scannerController.dispose();
  }
}

