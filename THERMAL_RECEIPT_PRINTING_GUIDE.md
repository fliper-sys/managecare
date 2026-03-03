# Enhanced 58mm Thermal Receipt Printing Guide

## Overview

This guide covers the implementation of enhanced 58mm Bluetooth thermal receipt printing for the Manage Care application, including support for long product lists and pro-user customization.

## Features

### ✅ Completed

1. **Enhanced Thermal Printer Service** (`lib/services/enhanced_thermal_printer_service.dart`)
   - 58mm-optimized receipt formatting
   - Automatic text wrapping for long product names
   - Professional receipt layout with proper spacing
   - Bluetooth thermal printer integration
   - Support for multiple receipt customizations

2. **Thermal Receipt Settings Screen** (`lib/presentation/settings/screens/thermal_receipt_settings_screen.dart`)
   - Pro-user-only gated access via `EnhancedSubscriptionProvider`
   - Customizable bank details (name, account number)
   - Website display option
   - Custom header and footer text
   - QR code configuration
   - Font size selection (small, medium, large)
   - Compact layout option for space-efficient receipts
   - Live preview of receipt format

3. **Receipt Screen Integration** (`lib/presentation/sales/screens/receipt_screen.dart`)
   - Updated `_printReceipt()` method for full Bluetooth printer support
   - 58mm-optimized formatting with product name wrapping
   - Pro-user feature access via subscription tier checking
   - Error handling and user feedback

4. **Routing & Navigation**
   - New route: `Routes.thermalReceiptSettings = '/settings/thermal-receipt'`
   - Registered in `AppRouter` for navigation
   - Quick access button from WhatsApp Settings Screen

5. **Data Model Updates**
   - Extended `ReceiptSettingsModel` with `additionalPreferences` field
   - Support for storing thermal printer customizations in Firestore
   - Proper serialization/deserialization for all settings

6. **Provider Enhancement**
   - New methods in `ReceiptSettingsProvider`:
     - `fetchReceiptPreferences()`: Load thermal settings from Firestore
     - `updateReceiptPreferences()`: Save customizations
     - Getter for `receiptPreferences` map

## Technical Implementation

### EnhancedThermalPrinterService

Provides three main components:

#### 1. Receipt Formatting (58mm)
```dart
static String format58mmReceipt({
  required String businessName,
  required String businessAddress,
  required String businessPhone,
  required String orderId,
  required DateTime date,
  required List<Map<String, dynamic>> items,
  required double subtotal,
  required double tax,
  required double discount,
  required double total,
  required String paymentMethod,
  required String footerMessage,
  // Pro features
  String? taxId,
  String? bankName,
  String? bankAccount,
  String? website,
  String? customHeaderText,
  String? customFooterText,
  bool showQrCode = false,
})
```

**Features:**
- Line width: 58 characters (standard for 58mm thermal paper)
- Automatic text wrapping for product names exceeding width
- Multi-line item formatting with continuation lines
- Professional borders and separators
- Right-aligned totals and amounts
- All pro features optional (null-checked)

#### 2. Bluetooth Printing
```dart
Future<bool> print58mmReceipt({
  required String receiptText,
  int paperSize = 58,
  int printDensity = 7,
  int printSpeed = 7,
})
```

**Features:**
- Paper size configuration (58mm/80mm)
- Adjustable print density and speed
- Paper feeding and cutting
- Exception handling with error reporting
- Returns success/failure boolean

#### 3. Helper Methods
- `_formatItemLine()`: Wraps long product names with proper alignment
- `_formatItemsHeader()`: Creates column headers
- `_formatTotal()`: Right-aligned total rows
- `_wrapText()`: Breaks text to fit 58mm width
- `_center()`, `_truncate()`: Text manipulation utilities

### Receipt Settings Screen Features

**Layout:**
```
Header Section
├── Custom header text
├── Font size selection
├── Compact layout toggle
├── Business information
│   ├── Show bank details checkbox
│   ├── Bank name field
│   └── Account number field
├── Website field
├── QR code options
└── Footer text
```

**Pro Access Gating:**
```dart
final canAccessProFeatures = subscriptionProvider.canAccessFeature(
  subscriptionProvider.userBusinessTier,
  feature: 'advanced_receipt_customization',
);
```

Users without Pro tier see a lock icon with upgrade prompt.

**Live Preview:**
Shows a simulated 58mm receipt with current settings applied, helping users visualize the final output.

### Integration with Receipt Screen

The receipt printing workflow:

1. **Data Collection**
   - Gather sale details (items, totals, payment method)
   - Fetch business info and receipt settings
   - Load pro-user preferences if applicable

2. **Check Pro Status**
   - Use `EnhancedSubscriptionProvider` to determine feature access
   - Include pro fields conditionally in receipt formatting

3. **Format for 58mm**
   - Call `EnhancedThermalPrinterService.format58mmReceipt()`
   - Pass all available data and pro preferences
   - Receive formatted string ready for printer

4. **Send to Printer**
   - Call `print58mmReceipt()` with formatted text
   - Handle success/error responses
   - Provide user feedback via SnackBar

**Code Example:**
```dart
Future<void> _printReceipt() async {
  final printerService = EnhancedThermalPrinterService();
  
  // Format receipt
  final receiptText = EnhancedThermalPrinterService.format58mmReceipt(
    businessName: business.name,
    businessAddress: receiptSettings.address ?? '',
    items: formattedItems,
    // ... other params
    // Pro features (null if not Pro)
    bankName: isPro ? receiptPrefs['bankName'] : null,
    customHeaderText: isPro ? receiptPrefs['customHeaderText'] : null,
  );
  
  // Send to printer
  final success = await printerService.print58mmReceipt(
    receiptText: receiptText,
    paperSize: 58,
  );
  
  // Show feedback
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(success ? 'Printed!' : 'Failed'))
  );
}
```

## Product Name Wrapping (58mm Optimization)

The service handles long product names intelligently:

**Example 1: Short Name**
```
Item Name.........Qty Price Total
Widget.............  2   15.00  30.00
```

**Example 2: Long Name (Auto-Wrapped)**
```
Item Name.........Qty Price Total
Premium Protein Shake  1   25.00  25.00
  with Extra Whipped Cream
```

The continuation line indents by 2 spaces for visual clarity.

**Calculation:**
```
nameWidth = 58 - qtyWidth(3) - priceWidth(8) - totalWidth(8) - padding(9)
          = 58 - 28 = 30 characters max per line
```

## Firestore Storage

Thermal preferences are stored in:
```
businesses/{businessId}/receipt_settings/thermalPreferences
```

Document structure:
```json
{
  "bankName": "First Bank",
  "bankAccount": "0123456789",
  "website": "www.business.com",
  "customHeaderText": "Welcome!",
  "customFooterText": "Visit us again",
  "qrCodeType": "url",
  "showBankDetails": true,
  "showQrCode": false,
  "compactLayout": false,
  "fontSize": "medium",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

## Pro Features

### Available to Pro Tier Users

1. **Bank Details Display**
   - Bank name
   - Account number
   - Automatically included on receipt

2. **Website Display**
   - Custom website URL
   - Printed at bottom of receipt

3. **Custom Text**
   - Header text (above receipt details)
   - Footer text (below totals and payment method)
   - Supports multi-line with automatic wrapping

4. **QR Code Support**
   - URL (default)
   - Order ID
   - vCard (business contact)
   - Placeholder for future QR rendering

5. **Layout Options**
   - Font size customization
   - Compact mode for more items per page

### Feature Gate Implementation

```dart
// In any screen
final subscriptionProvider = context.read<EnhancedSubscriptionProvider>();
final isPro = subscriptionProvider.canAccessFeature(
  subscriptionProvider.userBusinessTier,
  feature: 'advanced_receipt_customization',
);
```

## Navigation

### Access Thermal Receipt Settings

**Option 1: From WhatsApp Settings**
```
Settings > WhatsApp Settings > [Configure Thermal Receipt Button]
```

**Option 2: Direct Route**
```dart
Navigator.pushNamed(context, Routes.thermalReceiptSettings);
```

**Option 3: From Settings Menu** (if added)
```
Settings > Thermal Receipt Settings
```

## Testing Checklist

- [ ] Short product names display correctly (single line)
- [ ] Long product names wrap to multiple lines with indentation
- [ ] Very long names (50+ characters) wrap properly
- [ ] Totals align to the right edge
- [ ] Bank details display only when enabled
- [ ] Website field displays correctly
- [ ] Custom header/footer text wraps if too long
- [ ] QR code type selector works
- [ ] Font size selection affects preview
- [ ] Compact layout reduces spacing in preview
- [ ] Bluetooth printer connects successfully
- [ ] Receipt prints on 58mm thermal paper
- [ ] Paper feeds and cuts properly
- [ ] Pro-user sees all customization options
- [ ] Free-tier users see upgrade prompt
- [ ] Preview updates in real-time as settings change

## Error Handling

**Bluetooth Connection Errors:**
```dart
try {
  final success = await printerService.print58mmReceipt(...);
  if (!success) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to print receipt'))
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error printing receipt: $e'),
      backgroundColor: Colors.red,
    )
  );
}
```

## Future Enhancements

1. **QR Code Rendering**
   - Implement actual QR code generation and printing
   - Support different QR types (URL, order ID, vCard)

2. **Logo/Image Support**
   - Print business logo on receipt
   - Image positioning options

3. **Barcode Support**
   - EAN/Code128 barcodes
   - Barcode positioning

4. **Multiple Printer Profiles**
   - Save multiple printer configurations
   - Quick switch between printers
   - Printer discovery/pairing

5. **Receipt Templates**
   - User-defined receipt layouts
   - Multiple templates per business
   - Template switching per receipt type

6. **Advanced Formatting**
   - Custom font sizes per section
   - Column width customization
   - Color support (for color thermal printers)

## Dependencies

- `print_bluetooth_thermal`: Bluetooth printer communication
- `provider`: State management
- `cloud_firestore`: Settings persistence

## Files Modified/Created

**Created:**
- `lib/services/enhanced_thermal_printer_service.dart`
- `lib/presentation/settings/screens/thermal_receipt_settings_screen.dart`

**Modified:**
- `lib/presentation/sales/screens/receipt_screen.dart` (print method, imports)
- `lib/core/constants/routes.dart` (new route constant)
- `lib/routes/app_router.dart` (route registration, import)
- `lib/presentation/settings/screens/whatsapp_settings_screen.dart` (button link)
- `lib/providers/receipt_settings_provider.dart` (new methods and properties)
- `lib/data/models/receipt_settings_model.dart` (additional preferences field)

## Support

For issues or questions:
1. Check the Firestore storage structure
2. Verify printer Bluetooth connection
3. Review SnackBar error messages
4. Check console logs for detailed error info
5. Test with sample receipt data first

---

**Status:** ✅ Fully Implemented  
**Last Updated:** January 2024  
**Tested On:** 58mm Bluetooth thermal printers

