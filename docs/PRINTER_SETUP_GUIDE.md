# Thermal Printer Setup & Connection Guide

## Overview
This guide explains how to connect and configure a Bluetooth thermal receipt printer with your Manage Care application.

## What You Need
- **Thermal Printer**: 58mm or 80mm paper width Bluetooth thermal printer (commonly used for receipts)
- **Android/iOS Device**: Smartphone or tablet with Bluetooth capability
- **Manage Care App**: Version with printer support enabled
- **Printer Power**: Ensure printer is fully charged or plugged in

---

## Step-by-Step Setup

### Step 1: Prepare Your Printer
1. **Power On**: Turn on your thermal printer and ensure it's charged.
2. **Bluetooth Mode**: Set the printer to Bluetooth pairing mode. Usually:
   - Hold the power button for 5-10 seconds until a blue LED blinks
   - Some printers have a dedicated Bluetooth button
   - Refer to your printer's manual if unsure
3. **Device Name**: Note the Bluetooth device name (typically something like "Thermal Printer" or the model number)

### Step 2: Pair Printer on Your Device

#### Android
1. Open **Settings** > **Bluetooth**
2. Ensure Bluetooth is **ON**
3. Tap **Pair new device** or **Scan for devices**
4. Wait for your printer to appear in the list
5. Tap the printer name to pair
6. A PIN may be requested (common default: **0000** or **1234**)
7. Once connected, you should see a checkmark next to the printer name

#### iOS
1. Open **Settings** > **Bluetooth**
2. Ensure Bluetooth is **ON**
3. Wait for your printer to appear under "Other Devices"
4. Tap the printer name to pair
5. A code may appear on both devices (confirm matching codes)
6. Once paired, the printer appears under "My Devices"

### Step 3: Connect Printer in Manage Care

1. Open the **Manage Care** app
2. Navigate to **Settings** > **Business Settings**
3. Scroll to **Printer Setup** section
4. Tap **Configure Thermal Printer**
5. You'll see the **Printer Connection Screen** with a setup guide

### Step 4: Scan for Printers in App

1. On the **Printer Connection Screen**, tap **Scan for Printers**
2. The app will search for available Bluetooth devices
3. Wait 2-3 seconds for results to appear
4. Your paired printer should appear in the list showing:
   - Printer name (e.g., "Thermal Printer 1")
   - MAC address (unique identifier, e.g., "00:1A:7D:DA:71:13")

### Step 5: Select & Connect

1. **Select Printer**: Tap the printer you want to use (a radio button will highlight)
2. **Test Connection**: Tap **Connect & Test**
3. **Status Message**: Watch for confirmation:
   - ✅ **Green**: "Printer connected and saved!" — Success!
   - ❌ **Red**: "Connection test failed" — Try again or check printer is on
   - ⚠️ **Orange**: "No printer configured" — Select a printer first

### Step 6: Verify Connection

If the test succeeds:
- The printer will print a test receipt saying "TEST PRINT\nPrinter Connected!"
- Your printer is now configured and ready for use
- Settings are automatically saved to your business profile

---

## Permissions Required

### Android (Android 12+)
The app needs these permissions (you'll be asked to grant):
- **BLUETOOTH**: Connect to Bluetooth devices
- **BLUETOOTH_SCAN**: Discover Bluetooth devices
- **BLUETOOTH_CONNECT**: Communicate with Bluetooth devices
- **LOCATION (approximate)**: For Bluetooth device discovery

Grant these permissions when prompted for the best experience.

### iOS
The app needs Bluetooth access:
- You'll see a prompt: "Manage Care would like to use Bluetooth"
- Tap **Allow** to grant permission
- Device will remember this choice

---

## Using Receipts After Sale

### Automatic Actions (When Printer is Configured)
After every transaction:
1. Complete a sale in **POS**, **Retail**, **Restaurant**, **Pharmacy**, or **Hotel** checkout
2. A **Receipt Actions Sheet** appears with options:
   - **Share**: Send receipt via text/email/messaging apps
   - **Email**: Send directly to customer (Pro feature)
   - **Print (Bluetooth)**: Prints directly to your thermal printer

### Manual Printing
To manually print a receipt:
1. Tap **Print (Bluetooth)** button
2. App connects to your configured printer
3. Receipt prints within 2-3 seconds
4. Status message confirms success

---

## Troubleshooting

### Printer Not Found
**Problem**: Printer doesn't appear in the scan results

**Solutions**:
- Ensure printer is powered on and in pairing mode (blue LED blinking)
- Check Bluetooth is enabled on your device
- Move device closer to printer (within 5-10 meters)
- Restart printer and try scanning again
- Verify printer was successfully paired in device Bluetooth settings first

### Connection Test Failed
**Problem**: Selected printer but test print failed

**Solutions**:
- Printer may have gone to sleep — power it on again
- Check printer paper — paper jam or empty tray
- Verify Bluetooth is still connected (check device Bluetooth settings)
- Try scanning and reconnecting again
- Restart the app

### Bluetooth Permissions Denied
**Problem**: App asks for Bluetooth permissions but you declined

**Solutions**:
- **Android**: Go to **Settings** > **Apps** > **Manage Care** > **Permissions** > enable **Bluetooth**
- **iOS**: Go to **Settings** > **Privacy** > **Bluetooth** > enable **Manage Care**

### Printer Keeps Disconnecting
**Problem**: Printer connects, then disconnects after a few minutes

**Solutions**:
- Check printer battery level — low battery can cause disconnection
- Reduce distance between device and printer
- Check for interference (move away from microwaves, WiFi routers)
- Update printer firmware if available
- Try re-pairing printer

### Receipt Won't Print
**Problem**: Print button pressed but nothing happens

**Solutions**:
- Confirm printer is powered on and has paper
- Re-run connection test (**Connect & Test** button)
- Check paper tray isn't empty
- Ensure printer isn't in an error state (check printer display)
- Try restarting both app and printer

---

## Paper Specifications

### Paper Widths Supported
- **58mm**: Compact thermal rolls (common for smaller businesses)
- **80mm**: Standard thermal rolls (most common for retail/restaurants)

### Paper Types
- Standard thermal paper rolls (most common)
- Paper width should match your printer model
- Recommended: Plain thermal paper without coating for best results

### Paper Configuration in App
The app automatically detects and adapts receipt formatting based on configured paper width in Receipt Settings.

---

## Pro Tips

1. **Test First**: Always do a test print before your first transaction
2. **Keep Charged**: Ensure thermal printer is charged daily
3. **Paper Supply**: Keep spare paper rolls on hand
4. **Dark Location**: Keep the app in a safe location while setting up Bluetooth (dark backgrounds help visibility of LED states)
5. **PIN Code**: If printer asks for a PIN during pairing, common defaults are 0000, 1111, or 8888
6. **Automatic Printing**: You can enable "Auto-Connect Bluetooth" in Receipt Settings for automatic printing after sales (optional)

---

## FAQs

**Q: Can I connect multiple printers?**
A: Currently, the app supports one primary printer per business. You can reconfigure to a different printer anytime in the Printer Connection Screen.

**Q: Do I need WiFi for printing?**
A: No, Bluetooth printing works completely offline. However, emailing receipts requires internet connection.

**Q: What if my printer model isn't listed?**
A: The app scans all available Bluetooth devices. If your printer is paired to your device, it should appear. Ensure it's in pairing mode.

**Q: Can I print receipts without internet?**
A: Yes, local Bluetooth printing works without internet. Email and cloud sharing require internet.

**Q: How often do I need to re-pair?**
A: Once paired and configured in Manage Care, the connection persists. You typically only need to re-pair if you unpair the device in your device's Bluetooth settings.

---

## Support

For additional help:
- Check printer manual for model-specific pairing instructions
- Contact your printer manufacturer for firmware updates
- Reach out to support@managecareapp.com for app-specific issues

