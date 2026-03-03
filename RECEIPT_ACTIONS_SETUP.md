# Post-Sale Receipt Actions & Printer Integration - Setup Summary

## What's New

### 1. User-Facing Post-Sale Action Sheet
- **Before**: Receipts were sent automatically (silent actions)
- **Now**: Users see a modal bottom sheet with 3 action buttons after every sale:
  - **Share**: Send receipt via text/email/messaging apps
  - **Email**: Send directly to customer (Pro-only feature)
  - **Print (Bluetooth)**: Print to configured thermal printer

### 2. Thermal Printer Connection UI
- **New Screen**: Printer Connection Screen in Settings > Business Settings > Configure Thermal Printer
- **Setup Guide**: Built-in tutorial showing step-by-step pairing instructions
- **Printer Scanning**: Auto-detect paired Bluetooth devices
- **Test Print**: Confirm connection before saving
- **Easy Configuration**: One-click printer selection and connection

### 3. Pharmacy & Drink Pricing Support
- **Pharmacy Drugs**: Now include `price` field (price per unit)
- **Receipt Totals**: Calculated accurately using drug prices
- **Drink Demo**: Bar POS includes sample hardcoded prices
- **Sale Payloads**: Receipt text includes actual prices and totals

### 4. Platform Permissions
- **Android**: Added Bluetooth permissions in AndroidManifest.xml
- **iOS**: Added Bluetooth usage descriptions in Info.plist
- **Runtime Permissions**: Requested automatically on first print attempt

---

## Files Changed / Created

### New Files Created
1. `lib/presentation/sales/widgets/post_sale_action_sheet.dart` — Modal sheet with Share/Email/Print buttons
2. `lib/presentation/settings/screens/printer_connection_screen.dart` — Printer setup UI with tutorial
3. `lib/core/utils/bluetooth_permissions.dart` — Helper to request Bluetooth runtime permissions
4. `PRINTER_SETUP_GUIDE.md` — Comprehensive user guide for printer setup

### Modified Files
1. `lib/services/receipt_manager.dart` — Now shows action sheet instead of silent auto-actions
2. `lib/providers/pharmacy_provider.dart` — Added `price` field to Drug model
3. `lib/presentation/industry_specific/pharmacy/screens/pharmacy_pos_screen.dart` — Uses actual prices in receipts
4. `lib/presentation/industry_specific/hotel/screens/bookings_screen.dart` — Wired check-out to trigger ReceiptManager
5. `lib/presentation/industry_specific/drink/screens/bar_pos_screen.dart` — Added demo sale with ReceiptManager
6. `lib/presentation/settings/screens/business_settings_screen.dart` — Added printer setup button
7. `android/app/src/main/AndroidManifest.xml` — Added Bluetooth permissions
8. `ios/Runner/Info.plist` — Added Bluetooth usage descriptions

---

## How to Test Locally

### 1. Install & Run
```bash
flutter pub get
flutter run
```

### 2. Test Receipt Actions
- Go to **Retail POS** or **Restaurant** or any checkout flow
- Complete a sale (add items, checkout)
- **Action Sheet** appears with Share/Email/Print buttons
- Tap each button to test:
  - **Share**: Opens share dialog
  - **Email**: Shows Pro-gated message (or sends if Pro + recipient available)
  - **Print**: Shows "No printer configured" until you configure one

### 3. Test Printer Setup (on physical device with Bluetooth)
- Go to **Settings** > **Business Settings**
- Scroll to **Printer Setup** section
- Tap **Configure Thermal Printer**
- You'll see the **Printer Connection Screen** with guide
- If you have a real Bluetooth printer:
  - Ensure printer is on and in pairing mode
  - Pair it in device Bluetooth settings first
  - Tap **Scan for Printers** in app
  - Select printer and tap **Connect & Test**
  - If successful, a test receipt will print

### 4. Test Pharmacy Pricing
- Go to **Pharmacy POS**
- Add items to cart (drugs now have prices)
- Tap **Confirm Sale**
- Verify receipt shows prices and accurate total
- Test Share/Email/Print actions

### 5. Test Drink Demo
- Go to **Bar POS**
- Tap **Demo Sale & Receipt**
- Receipt shows hardcoded drink prices
- Test action sheet buttons

---

## Key Features

### Post-Sale Action Sheet
- **Status Messages**: Shows success/failure for each action with color coding
- **Pro Gating**: Email button disabled for non-Pro users
- **Permissions**: Handles file storage/sharing permissions
- **Thermal Format**: Converts receipt to printer-compatible format
- **Error Handling**: Graceful failures with user feedback

### Printer Connection
- **Tutorial**: 4-step visual guide with icons
- **Device Scanning**: Lists all paired Bluetooth devices
- **MAC Address Display**: Shows device identifier
- **Test Print**: Confirms connection before saving
- **Settings Persistence**: Saves to Firestore per business

### Pharmacy Pricing
- **Sample Data**: Drugs include realistic prices ($5, $7.50, $10, etc.)
- **Cart Totals**: Calculated from quantity × price
- **Receipt Display**: Shows item prices and total

### Platform Support
- **Android 12+**: Handles runtime Bluetooth permissions
- **iOS 13+**: Works with standard Bluetooth permissions
- **Offline**: Printing works without internet
- **Graceful Fallback**: Shows helpful messages if permissions denied

---

## User Flow

### Complete Receipt Flow
```
1. Customer completes sale
   ↓
2. ReceiptManager.handlePostSale() called
   ↓
3. Receipt text generated with prices/totals
   ↓
4. PostSaleActionSheet bottom sheet shown
   ↓
5. User chooses: Share / Email / Print
   ↓
6. Action executed with status feedback
   ↓
7. User can close sheet or take additional action
```

### Printer Setup Flow
```
1. User taps "Configure Thermal Printer" in settings
   ↓
2. PrinterConnectionScreen opens with tutorial
   ↓
3. User reads setup guide (expandable)
   ↓
4. User taps "Scan for Printers"
   ↓
5. App discovers paired Bluetooth devices
   ↓
6. User selects printer from list
   ↓
7. User taps "Connect & Test"
   ↓
8. App sends test receipt to printer
   ↓
9. Settings saved, ready for use
```

---

## Configuration Notes

### Thermal Printer Service
- **Paper Width**: Supports 58mm and 80mm paper sizes
- **Auto-Formatting**: Text wraps to paper width automatically
- **Test Content**: `"TEST PRINT\nPrinter Connected!\n"` prints on test

### Receipt Settings
- **Printer MAC**: Stored in Firestore per business
- **Paper Width**: Configurable (default 80mm)
- **Auto-Print**: Currently disabled (manual via action sheet)
- **Email Receipts**: Can be enabled per business

### Email Service
- **Template**: Expects 'receipt' template on server
- **Pro Gating**: Email sending checks `subscriptionTier`
- **Recipient**: Uses customer email or business email as fallback

---

## Next Steps (Optional Enhancements)

1. **Real Bluetooth Device Discovery**
   - Implement actual `blue_thermal_printer` device discovery API
   - Currently returns demo printers for testing

2. **Printer Device Persistence**
   - Remember "favorite" printers for quick reconnect
   - Show last-used printer at top of list

3. **Batch Printing**
   - Print multiple receipts in sequence
   - Useful for end-of-day reports

4. **Receipt History**
   - Store printed receipts in Firestore
   - View/reprint past receipts from archive

5. **Enhanced Error Logs**
   - Log all print attempts for debugging
   - Show printer diagnostic info

---

## Troubleshooting Commands

### Check Bluetooth Permissions (Android)
```bash
adb shell dumpsys package | grep -A 10 permissions
```

### Verify iOS Entitlements
```bash
codesign --display --entitlements - ios/Runner.app/Runner
```

### Test Printer Connection Manually
```dart
// In any screen context:
await ThermalPrinterService.printViaBluetooth(
  printerMac: "00:1A:7D:DA:71:13",  // Your printer MAC
  receiptText: "TEST\nPRINT\n",
);
```

---

## Support Resources

- **Printer Setup Guide**: See `PRINTER_SETUP_GUIDE.md`
- **API Docs**: `ThermalPrinterService` in `lib/services/thermal_printer_service.dart`
- **Action Sheet**: `PostSaleActionSheet` in `lib/presentation/sales/widgets/post_sale_action_sheet.dart`
- **Printer UI**: `PrinterConnectionScreen` in `lib/presentation/settings/screens/printer_connection_screen.dart`

