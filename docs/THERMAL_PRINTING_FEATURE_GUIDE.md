# Thermal Printing Feature Documentation

## Overview
The thermal printing feature provides comprehensive support for thermal printer operations across **Web** and **Android** platforms. It includes ESC/POS command generation, device management, and complete receipt printing functionality.

## Components

### 1. **ThermalPrinterManager** (`lib/services/thermal_printer_manager.dart`)
Core manager for printer operations with platform-specific implementations.

**Key Features:**
- Printer discovery and connection
- Cross-platform support (Web & Android)
- Printer status monitoring
- Raw ESC/POS printing support

**Key Classes:**
- `ThermalPrinterManager`: Singleton printer manager
- `PrinterStatus`: Enum for printer states
- `ThermalPrinterDevice`: Printer device model
- `PrinterPlatformImpl`: Platform-specific implementation interface
- `WebPrinterImpl`: Web platform implementation
- `AndroidPrinterImpl`: Android platform implementation

### 2. **EscPosReceiptGenerator** (`lib/services/esc_pos_receipt_generator.dart`)
Generates ESC/POS commands for thermal receipt printing.

**Key Features:**
- Complete receipt generation with formatting
- Support for 58mm and 80mm paper widths
- Item listing with quantities and prices
- Tax, discount, and total calculations
- Custom headers and footers
- ESC/POS command generation

**Key Classes:**
- `EscPosReceiptGenerator`: Main receipt generator
- `ReceiptLineItem`: Receipt item model
- `EscPosBuffer`: Buffer for building ESC/POS commands
- `EscPosAlignment`: Text alignment enum
- `EscPosFontSize`: Font size enum

### 3. **ThermalPrintingService** (`lib/services/thermal_printing_service.dart`)
High-level service combining all thermal printing functionality.

**Key Features:**
- Unified interface for all printing operations
- Automatic initialization
- Test receipt generation
- Connection testing
- Status reporting

## Quick Start

### Basic Usage

```dart
import 'package:business_manager/services/thermal_printing_service.dart';
import 'package:business_manager/services/esc_pos_receipt_generator.dart';

// Get service instance
final printingService = ThermalPrintingService();

// Initialize
await printingService.initialize();

// Print full receipt
final success = await printingService.printFullReceipt(
  businessName: 'My Store',
  receiptNumber: 'REC-001',
  receiptDate: DateTime.now(),
  items: [
    ReceiptLineItem(
      name: 'Product',
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

print('Print success: $success');
```

### Printer Discovery and Connection

```dart
// Get available printers
final printers = await printingService.getAvailablePrinters();

// Connect to first printer
if (printers.isNotEmpty) {
  await printingService.connectToPrinter(printers[0]);
}

// Test connection
final testResult = await printingService.testPrinterConnection();
print('Connection test: ${testResult.isSuccessful}');
```

### Platform-Specific Implementation

#### Web Platform
```dart
final webPrinter = WebPrinterImpl();
await webPrinter.initialize();
// Web uses system print dialog
```

#### Android Platform
```dart
final androidPrinter = AndroidPrinterImpl();
await androidPrinter.initialize();
final devices = await androidPrinter.discoverPrinters();
```

## ESC/POS Commands Reference

The following ESC/POS commands are supported:

| Command | Code | Description |
|---------|------|-------------|
| ESC @ | [0x1B, 0x40] | Initialize printer |
| ESC a | [0x1B, 0x61, n] | Set alignment (0=left, 1=center, 2=right) |
| ESC E | [0x1B, 0x45, n] | Bold mode (0=off, 1=on) |
| ESC - | [0x1B, 0x2D, n] | Underline (0=off, 1=on) |
| ESC ! | [0x1B, 0x21, n] | Font size/style |
| GS V | [0x1D, 0x56, n] | Cut paper (0=full cut, 1=partial) |
| LF | [0x0A] | Line feed |

## Paper Sizes

### 58mm Thermal Paper
- Characters per line: 30
- Standard for POS receipts
- Narrower format

### 80mm Thermal Paper
- Characters per line: 48
- Wider format
- More content per line

## Testing

### Running Tests

Run all thermal printing tests:
```bash
flutter test test/services/thermal_printer_manager_test.dart
flutter test test/services/esc_pos_receipt_generator_test.dart
flutter test test/services/thermal_printing_service_integration_test.dart
```

### Test Coverage

The test suite includes:

1. **ThermalPrinterManager Tests** (25+ tests)
   - Singleton pattern validation
   - Status management
   - Printer discovery
   - Connection/disconnection
   - Platform implementations

2. **EscPosReceiptGenerator Tests** (35+ tests)
   - Receipt generation
   - ESC/POS command validation
   - Multiple items handling
   - Paper width support
   - Formatting and alignment

3. **ThermalPrintingService Integration Tests** (30+ tests)
   - Service initialization
   - Print operations
   - Error handling
   - Test result validation

### Test Execution Examples

#### Basic Manager Test
```dart
test('Singleton instance returns same object', () {
  final instance1 = ThermalPrinterManager();
  final instance2 = ThermalPrinterManager();
  expect(identical(instance1, instance2), true);
});
```

#### Receipt Generation Test
```dart
test('Generate receipt returns Uint8List', () {
  final receipt = EscPosReceiptGenerator.generateReceipt(
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
  expect(receipt, isA<Uint8List>());
  expect(receipt.length, greaterThan(0));
});
```

#### Integration Test
```dart
test('Print full receipt returns boolean', () async {
  await printingService.initialize();
  final result = await printingService.printFullReceipt(
    businessName: 'Test Business',
    receiptNumber: '001',
    receiptDate: DateTime.now(),
    items: [...],
    subtotal: 10.0,
    tax: 1.0,
    discount: 0.0,
    total: 11.0,
    paymentMethod: 'Cash',
  );
  expect(result, isA<bool>());
});
```

## Integration with Existing Features

### With Post-Sale Action Sheet
```dart
// In post_sale_action_sheet.dart
import 'package:business_manager/services/thermal_printing_service.dart';

// Use thermal printing
final printingService = ThermalPrintingService();
await printingService.initialize();

// Print receipt
await printingService.printTextReceipt(
  receiptText: receiptText,
  businessName: businessName,
);
```

### With Receipt Settings
```dart
// Support different paper widths from settings
final paperWidth = receiptSettings.paperWidth ?? 58;

await printingService.printFullReceipt(
  // ... other parameters
  paperWidth: paperWidth,
);
```

## Dependencies Added

```yaml
# Thermal Printing
esc_pos_utils: ^1.3.0
esc_pos_bluetooth: ^0.0.9
usb_thermal_printer: ^1.0.0
```

## Error Handling

### Connection Errors
```dart
try {
  final result = await printingService.testPrinterConnection();
  if (!result.isSuccessful) {
    print('Connection failed: ${result.error}');
    print('Status: ${result.status}');
  }
} catch (e) {
  print('Error: $e');
}
```

### Print Errors
```dart
try {
  final success = await printingService.printFullReceipt(...);
  if (!success) {
    print('Print failed - printer may be disconnected');
  }
} catch (e) {
  print('Print error: $e');
}
```

## Platform-Specific Notes

### Android
- Supports Bluetooth thermal printers
- Requires BLUETOOTH permission
- Supports USB thermal printers with appropriate driver

### Web
- Uses system print dialog
- No printer discovery available
- Print preview before sending to printer

## Advanced Usage

### Custom Receipt Format
```dart
// Generate custom ESC/POS commands
final buffer = EscPosBuffer(58);
buffer.initializePrinter();
buffer.setAlignment(EscPosAlignment.center);
buffer.printText('Custom Header', bold: true);
buffer.printDashedLine();
buffer.setAlignment(EscPosAlignment.left);
buffer.printText('Custom content...');
buffer.cutPaper();

final bytes = buffer.getBytes();
await printingService.printRawBytes(bytes);
```

### Raw Bytes Printing
```dart
// Print raw ESC/POS bytes directly
final bytes = Uint8List.fromList([0x1B, 0x40]); // Initialize
await printingService.printRawBytes(bytes);
```

## Troubleshooting

### Printer Not Found
- Ensure printer is powered on
- Check Bluetooth connection (Android)
- Verify network connection (network printers)

### Print Not Appearing
- Test connection first
- Check paper loading
- Verify printer buffer isn't full

### Connection Lost
- Reconnect to printer
- Check physical connection
- Restart printer if necessary

## Performance Considerations

1. **Initialization**: Happens automatically on first use
2. **Discovery**: May take a few seconds on Android
3. **Printing**: ESC/POS format is efficient and fast
4. **Memory**: Receipt bytes are typically < 5KB

## Future Enhancements

- QR code support
- Image printing
- Receipt templates
- Print queue management
- Network printer support
- Receipt reprinting capability

## File Structure

```
lib/services/
├── thermal_printer_manager.dart      # Core manager
├── esc_pos_receipt_generator.dart    # Receipt generation
├── thermal_printing_service.dart     # High-level service

test/services/
├── thermal_printer_manager_test.dart              # 25+ tests
├── esc_pos_receipt_generator_test.dart           # 35+ tests
└── thermal_printing_service_integration_test.dart # 30+ tests
```

## Summary

The thermal printing feature provides:
- ✅ Cross-platform support (Web + Android)
- ✅ Complete ESC/POS command generation
- ✅ Automatic receipt formatting
- ✅ Printer discovery and management
- ✅ Comprehensive test coverage (90+ tests)
- ✅ Error handling and status reporting
- ✅ Easy integration with existing features
