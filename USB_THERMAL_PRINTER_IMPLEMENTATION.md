# USB Thermal Printer Integration Guide

## Overview

The Manage Care app now uses Flutter's **`printing` package** for direct USB/thermal printer support, replacing the browser-based WebUSB printer.js implementation. This approach provides:

✅ **Direct USB printing** to thermal printers  
✅ **Exact PDF sizing** - no paper wastage  
✅ **Cross-platform support** (Android, iOS, Windows, Linux, Web)  
✅ **Proper thermal receipt formatting**  
✅ **Automatic paper size detection**  

---

## Architecture

### Service Structure

```
lib/services/
├── printer_service.dart                      # Main printer service
├── usb_thermal_printer_service.dart          # USB/thermal printer implementation
├── thermal_receipt_pdf_generator.dart        # PDF generation for receipts
├── thermal_printer_utils.dart                # Constants and utilities
└── web_usb_printer.dart                      # (Legacy - kept for compatibility)
```

### Key Components

#### 1. **UsbThermalPrinterService**
Handles all USB/thermal printer operations:
- Detect available printers
- Select specific printer
- Test printer connection
- Generate thermal PDFs
- Send PDFs to printer
- Save PDFs to file

#### 2. **ThermalReceiptPdfGenerator**
Creates perfectly sized PDFs:
- Calculates exact page dimensions based on content
- Minimizes paper waste
- Uses monospace font (Courier) for thermal receipt readability
- Supports custom headers/footers
- Supports QR codes

#### 3. **ThermalPrinterUtils**
Centralized constants and helpers:
- Paper widths (58mm, 80mm)
- Character per line calculations
- Text formatting utilities
- Receipt layout specifications
- Conversion utilities (mm ↔ PDF points)

---

## Setup Instructions

### 1. Dependency Already Added

The `printing` package is already in `pubspec.yaml`:

```yaml
dependencies:
  printing: ^5.14.2
```

If not, add it:
```bash
flutter pub add printing
```

### 2. Platform-Specific Setup

#### **Android**
Add to `android/app/build.gradle`:
```gradle
android {
    compileSdkVersion 33  // or higher
}
```

Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

#### **iOS**
No additional setup required. The printing package handles it.

#### **Windows/Linux**
Native printer support is automatic via system printing.

#### **Web**
Uses browser's print dialog and system printer access.

---

## Usage Examples

### Initialize Printer Service

```dart
import 'package:business_manager/services/printer_service.dart';

final printerService = PrinterService();

// Initialize with settings
printerService.initialize(
  printerName: 'XP-58 USB',           // Optional
  printerModel: 'XP-58',
  connectionType: 'usb',               // or 'thermal'
  paperWidth: 58,                      // mm
  autoConnect: true,
  businessName: 'Your Business',
  headerText: 'Welcome to Our Store',
  footerText: 'Thank you for your business!',
);
```

### Test Printer Connection

```dart
final result = await printerService.testConnection();

if (result['success']) {
  print('Printer connected: ${result['printerName']}');
  print('Available printers: ${result['availablePrinters']}');
} else {
  print('Error: ${result['error']}');
}
```

### Print Receipt

```dart
// SaleModel sale is your transaction data
final printResult = await printerService.printReceipt(
  sale,
  saveToFile: true,  // Also save PDF to device
);

if (printResult['success']) {
  print('Receipt printed successfully');
  // Show success message to user
} else {
  print('Print error: ${printResult['error']}');
  // Show error message to user
}
```

### Select Specific Printer

```dart
// Get available printers
final printers = await printerService.getAvailablePrinters();
print('Available printers: $printers');

// Select one
await printerService.selectPrinter('Brother HL-L8360CDW');
```

### Save Receipt PDF Without Printing

```dart
final pdfBytes = await printerService._generateThermalReceiptPdf(sale);
final filePath = await usbPrinter.saveThermalReceiptPdf(
  pdfBytes: pdfBytes,
  receiptNumber: sale.receiptNumber,
);
print('PDF saved to: $filePath');
```

---

## PDF Sizing Details

### How It Works

1. **Content Calculation**
   - Count items in receipt
   - Check for discounts/taxes
   - Account for custom headers/footers
   - Estimate QR code space if needed

2. **Height Calculation**
   ```
   Height = (
       header (15mm) +
       items (4mm each) +
       totals section (20mm) +
       footer (10mm) +
       extras (discounts, tax, QR, custom text)
   )
   Clamp to 80-200mm range
   ```

3. **Width Fixed**
   - 58mm or 80mm based on printer setting
   - Exactly matched to thermal paper size

4. **Result**
   - PDF dimensions exactly match paper
   - No margins wasted
   - No content cut off
   - Minimal paper waste

### Example Calculations

For a receipt with 5 items:
```
Base height: 50mm
Items: 5 × 4mm = 20mm
Discount: 3mm
Tax: 3mm
Total height: 76mm → clamped to minimum 80mm
Final PDF: 58mm × 80mm
```

---

## Thermal Printer Specifications

### Supported Paper Sizes

| Width | Characters/Line | Use Case |
|-------|-----------------|----------|
| 58mm | 30 chars | Compact receipts, small items |
| 80mm | 48 chars | Standard receipts, detailed info |

### Character Per Line

```dart
// From ThermalPrinterSpecs
charsPerLineMap = {
  58: 30,  // 58mm paper
  80: 48,  // 80mm paper
};

// Get for specific width
int chars = ThermalPrinterSpecs.getCharsPerLine(58);  // Returns 30
```

### Point/MM Conversion

```dart
const double pointsPerMm = 2.834645669;

// Convert
double ptWidth = ThermalPrinterSpecs.mmToPoints(58);     // ~164.5 points
double mmHeight = ThermalPrinterSpecs.pointsToMm(283);   // ~100 mm
```

---

## Configuration

### Printer Settings Screen Integration

Update your printer settings screen to use the new service:

```dart
class PrinterSettingsScreen extends StatefulWidget {
  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = PrinterService();
  List<String> _availablePrinters = [];

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    final printers = await _printerService.getAvailablePrinters();
    setState(() => _availablePrinters = printers);
  }

  Future<void> _testConnection() async {
    final result = await _printerService.testConnection();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['success'] ? 'Success' : 'Error'),
        content: Text(
          result['success']
              ? 'Connected to ${result['printerName']}'
              : result['error'] ?? 'Unknown error'
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Printer selection dropdown
          DropdownButton<String>(
            isExpanded: true,
            items: _availablePrinters
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p),
                    ))
                .toList(),
            onChanged: (value) async {
              if (value != null) {
                await _printerService.selectPrinter(value);
              }
            },
            hint: const Text('Select printer'),
          ),
          
          const SizedBox(height: 16),
          
          // Test button
          ElevatedButton(
            onPressed: _testConnection,
            child: const Text('Test Printer Connection'),
          ),
        ],
      ),
    );
  }
}
```

---

## Migration from WebUSB

### What Changed

| Old (WebUSB) | New (Printing Package) |
|--------------|----------------------|
| Browser-only | Cross-platform |
| ESC/POS text format | PDF format |
| Limited sizing control | Exact PDF sizing |
| JavaScript dependency | Pure Dart/Flutter |
| No file saving | Save PDFs easily |

### Remove Old Code

1. **Delete** (no longer needed):
   ```
   lib/services/web_usb_printer.dart
   lib/services/web_usb_printer_web.dart
   lib/services/web_usb_printer_stub.dart
   ```

2. **Update imports** in files that imported WebUSB:
   - Change from `web_usb_printer.dart` imports
   - To `usb_thermal_printer_service.dart` / `printer_service.dart`

3. **Verify** no remaining references:
   ```bash
   grep -r "web_usb_printer" lib/
   grep -r "WebUsbPrinter" lib/
   grep -r "printer.js" lib/
   ```

---

## Testing

### Test Cases

```dart
// Test 1: Get available printers
test('Should list available printers', () async {
  final service = UsbThermalPrinterService();
  final printers = await service.getAvailablePrinters();
  expect(printers, isNotEmpty);
});

// Test 2: Generate PDF with exact sizing
test('Should generate PDF with correct dimensions', () async {
  final pdf = await ThermalReceiptPdfGenerator.generateReceiptPdf(
    businessName: 'Test Store',
    receiptNumber: 'RCP001',
    receiptDate: DateTime.now(),
    items: [
      ReceiptItem(name: 'Item 1', quantity: 2, price: 100.0),
      ReceiptItem(name: 'Item 2', quantity: 1, price: 50.0),
    ],
    subtotal: 250.0,
    tax: 25.0,
    discount: 0.0,
    total: 275.0,
    paymentMethod: 'Cash',
    customerName: 'Test Customer',
    paperWidth: 58,
  );
  
  expect(pdf, isNotNull);
  expect(pdf.length, greaterThan(0));
});

// Test 3: Printer connection
test('Should test printer connection', () async {
  final service = PrinterService();
  service.initialize(
    printerName: 'Test Printer',
    printerModel: 'XP-58',
    connectionType: 'usb',
  );
  
  final result = await service.testConnection();
  expect(result, isA<Map>());
  expect(result['success'], isA<bool>());
});
```

### Manual Testing

1. **Connect thermal printer** via USB
2. **Run app** in debug mode
3. **Go to Printer Settings**
4. **Select printer** from dropdown
5. **Click "Test Connection"**
6. **Create a sale/receipt**
7. **Print receipt**
8. **Verify PDF output**

---

## Troubleshooting

### "No printers available"

**Cause:** Printer not detected or not connected

**Solutions:**
1. Check USB connection
2. Install printer drivers (Windows)
3. Restart app
4. Restart device

### "WebUSB not available"

**This should not appear** with new implementation. If you see this, you're still using old WebUSB code.

**Solution:** Update imports to use `UsbThermalPrinterService` instead.

### PDF not printing

**Causes:**
- Printer disconnected
- Paper jam
- No toner/ink
- Printer not selected

**Solutions:**
1. Check printer status light
2. Test with system print dialog
3. Clear printer queue
4. Restart printer

### Text cut off on receipt

**Cause:** Character width estimation mismatch

**Solution:** Adjust `charsPerLineMap` in `ThermalPrinterSpecs`

```dart
// From 30 chars to 28 chars for 58mm
charsPerLineMap = {
  58: 28,  // Reduced from 30
  80: 48,
};
```

### Paper waste/excessive blank space

**Cause:** Incorrect height calculation

**Solution:** Review `ThermalReceiptLayout.calculateHeight()` and adjust factors:

```dart
static const double itemLineHeightMm = 4;  // Adjust based on actual output
```

---

## API Reference

### PrinterService

```dart
class PrinterService {
  // Initialization
  void initialize({
    required String printerName,
    required String printerModel,
    required String connectionType,
    int paperWidth = 58,
    bool autoConnect = true,
    String? headerText,
    String? footerText,
    String? businessName,
  })
  
  // Connection
  Future<Map<String, dynamic>> testConnection()
  Future<bool> selectPrinter(String? printerName)
  Future<List<String>> getAvailablePrinters()
  
  // Printing
  Future<Map<String, dynamic>> printReceipt(
    SaleModel sale,
    {bool autoOpen = false, bool saveToFile = true}
  )
  
  // Configuration
  void setHeaderText(String? text)
  void setFooterText(String? text)
  void setBusinessName(String name)
  Map<String, dynamic> getPrinterConfig()
}
```

### UsbThermalPrinterService

```dart
class UsbThermalPrinterService {
  // Initialization
  void initialize({
    String? printerName,
    int paperWidth = 58,
    bool autoDetectPrinter = true,
  })
  
  // Device operations
  Future<List<Printer>> getAvailablePrinters()
  Future<bool> selectPrinter(String? printerName)
  Future<Map<String, dynamic>> testPrinterConnection()
  
  // PDF generation
  Future<Uint8List> generateThermalReceiptPdf({...})
  
  // Printing & storage
  Future<Map<String, dynamic>> printThermalReceipt({
    required Uint8List pdfBytes,
    required String receiptName,
  })
  Future<String> saveThermalReceiptPdf({
    required Uint8List pdfBytes,
    required String receiptNumber,
    String? outputDirectory,
  })
}
```

### ThermalReceiptPdfGenerator

```dart
class ThermalReceiptPdfGenerator {
  static Future<Uint8List> generateReceiptPdf({
    required String businessName,
    required String receiptNumber,
    required DateTime receiptDate,
    required List<ReceiptItem> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    required String customerName,
    int paperWidth = 58,
    String? customHeader,
    String? customFooter,
    bool showQrCode = false,
    String? qrCodeUrl,
  })
}
```

---

## Performance Optimization

### PDF Generation
- Monospace font (Courier) renders faster
- Minimal formatting reduces file size
- Content-based height calculation prevents oversized PDFs

### Printing
- Direct USB communication is faster than API calls
- No network latency
- Local device access

### File Storage
- PDFs saved locally for quick retrieval
- No cloud upload overhead
- User can access receipts offline

---

## Future Enhancements

- [ ] QR code integration for receipt tracking
- [ ] Barcode printing support
- [ ] Logo image in receipt header
- [ ] Network printer support
- [ ] Bluetooth thermal printer support
- [ ] Template customization UI
- [ ] Batch receipt printing
- [ ] Receipt archival system

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review service logs in debug output
3. Test printer with system print dialog
4. Check manufacturer documentation for printer model
5. Verify permissions on mobile platforms

---

## References

- [Flutter Printing Package](https://pub.dev/packages/printing)
- [Thermal Printer Standards](https://en.wikipedia.org/wiki/Thermal_printing)
- [ESC/POS Command Set](https://www.epson.com/cgi-bin/Store/pl/c_1070_support_type/-/support-type/manuals)
- [PDF Specification](https://www.adobe.io/content/dam/udp/assets/open/pdf/spec/PDF32000_2008.pdf)
