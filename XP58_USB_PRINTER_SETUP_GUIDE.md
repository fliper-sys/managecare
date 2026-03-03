# XP-58 USB Printer Setup & Troubleshooting Guide

## Overview
The Manage Care application now has improved USB printer support for the Xprinter XP-58 thermal receipt printer. This guide will help you set up, configure, and troubleshoot the printer.

## System Requirements

### Browser Requirements (WebUSB)
- **Chrome 61+** or **Microsoft Edge 79+** (recommended)
- Connection must be **HTTPS** (or localhost for development)
- **NOT** supported in:
  - Firefox
  - Safari
  - Incognito/Private browsing mode
  - HTTP connections (must use HTTPS)

### USB Connection
- USB 2.0+ cable connected directly to computer
- Xprinter XP-58 printer powered on
- Proper USB drivers may be required (varies by OS)

## Step 1: Initial Setup

### 1.1 Enable Printer in App
1. Open Manage Care application
2. Go to **Settings** → **Printer Settings**
3. Toggle **"Printer Active"** to **ON**
4. Select **Printer Model**: "Thermal Receipt Printer"
5. Select **Connection Type**: "USB"

### 1.2 Pair USB Printer
1. In Printer Settings, click **"Pair USB Printer"** button
2. Browser will show a device selection dialog
3. Select **"Xprinter (XP-58)"** or similar from the list
   - Device name typically shows vendor ID and product ID
4. Click **"Select"** or **"Connect"** in the dialog
5. You should see success message: "Selected USB printer: [name]"

### 1.3 Test Connection
1. Click **"Test USB Printer"** button
2. Receipt printer should print a test page
3. Success message will show bytes sent

---

## Step 2: Configuration

### Paper Width
- **Default**: 58mm (standard for XP-58)
- Adjust if needed for different paper sizes

### Auto-Connect
- **Enabled**: App will attempt to connect automatically
- **Disabled**: Manual selection required each time

### Header & Footer Text
- Optional: Add business name or closing message
- Appears on all printed receipts

---

## Troubleshooting

### ❌ "USB Access Denied" Error

**Cause**: Browser WebUSB permission was denied or revoked.

**Solutions**:
1. **First-time access**: Browser should show a permission prompt
   - If it doesn't appear, try again
   - Make sure you're not in incognito/private mode

2. **Permission revoked**: Re-grant permission
   - Click "Pair USB Printer" again
   - Select the printer when prompted
   - Grant permission when browser asks

3. **Chrome/Edge setting check**:
   - Open `chrome://settings/content/usbDevices` (Chrome)
   - Open `edge://settings/content/usbDevices` (Edge)
   - Ensure USB device access is enabled
   - Remove blocked entries for your printer

### ❌ "WebUSB not available in this browser"

**Cause**: Browser doesn't support WebUSB or wrong connection method.

**Solutions**:
- Use **Chrome 61+** or **Edge 79+**
- Make sure URL is **HTTPS** (not HTTP)
- For localhost testing, HTTP is allowed
- **Don't use**: Firefox, Safari, incognito/private mode

### ❌ "Device not found" or "Printer Disconnected"

**Cause**: USB cable unplugged or printer turned off.

**Solutions**:
1. Check USB cable connection:
   - Disconnect and reconnect USB cable
   - Try a different USB port
   - Check for damaged cable

2. Power cycle printer:
   - Turn off XP-58
   - Wait 10 seconds
   - Turn on and wait for it to warm up

3. Refresh device list:
   - Click "Refresh Devices" in Printer Settings
   - Should show your printer after reconnection

4. Restart browser/app:
   - Close tab and reopen
   - Try "Pair USB Printer" again

### ❌ "USB Communication Error" or "Transfer Failed"

**Cause**: Communication issue between browser and printer.

**Solutions**:
1. **Restart the printer**:
   - Power off XP-58
   - Wait 10 seconds
   - Power on and let it fully initialize

2. **Retry printing**:
   - App automatically retries 2 times
   - If still fails, try again in 30 seconds

3. **Check USB quality**:
   - Replace USB cable if old
   - Use original or high-quality cable
   - Avoid cheap/damaged cables

4. **Update printer firmware**:
   - Check Xprinter support site for firmware updates
   - Follow Xprinter's update instructions

### ❌ "WebUSB not supported in this browser"

**Cause**: Using unsupported browser or connection.

**Solutions**:
- Install **Google Chrome** or **Microsoft Edge**
- Use HTTPS (not HTTP) except on localhost
- Exit incognito/private browsing mode

### ❌ Printer appears in list but won't print

**Cause**: Browser lost connection to device.

**Solutions**:
1. Click "Refresh Devices"
2. Try re-pairing the printer
3. Check if USB cable is properly seated
4. Restart browser and retry

### ❌ No devices found when refreshing

**Cause**: Printer not connected or not recognized.

**Solutions**:
1. Check physical USB connection
2. Try different USB port
3. Verify printer is powered on
4. Check Device Manager (Windows):
   - Open Device Manager
   - Look for "Xprinter" or unknown USB device
   - If unknown, install drivers from Xprinter website

---

## Step 3: Printing Workflow

### Normal Receipt Printing
1. Complete a sale in the app
2. Click **"Print Receipt"** or **"Print"**
3. Select printer as needed
4. Receipt prints automatically

### Test Print
1. Go to **Settings** → **Printer Settings**
2. Click **"Test USB Printer"**
3. Verify receipt prints correctly
4. Check formatting and alignment

### Troubleshoot Print Issues
If receipts don't print:
1. Click **"Test USB Printer"** first
2. If test prints, issue is with receipt data
3. If test doesn't print, issue is with USB connection
4. Follow relevant troubleshooting above

---

## Windows Driver Setup (if needed)

Some Windows systems may need USB printer drivers:

1. **Check Device Manager**:
   - Right-click Start menu
   - Select "Device Manager"
   - Look for Xprinter or "Unknown USB Device"

2. **Install Drivers** (if needed):
   - Visit Xprinter official website
   - Download Windows drivers for XP-58
   - Run installer and follow prompts
   - Restart computer

3. **Verify Installation**:
   - Device Manager should show "Xprinter XP-58"
   - No yellow warning icons

---

## Advanced Troubleshooting

### Check Browser Console for Errors
1. **Chrome/Edge**: Press `F12` to open Developer Tools
2. Go to **Console** tab
3. Look for error messages
4. Search for "usb" or "printer"
5. Share error message for support

### Test WebUSB Support
1. Open Chrome DevTools (F12)
2. Go to **Console** tab
3. Paste: `navigator.usb ? "Supported" : "Not supported"`
4. Press Enter
5. Should show "Supported"

### Get Device Information
1. Open Settings → Printer Settings
2. Click "Refresh Devices"
3. Look at device list
4. Note Device ID and Product Name
5. Use for troubleshooting reference

---

## FAQ

**Q: Why can't I use the printer in Firefox?**
A: Firefox doesn't support WebUSB API yet. Use Chrome or Edge.

**Q: Works on Chrome but not Edge?**
A: Both support WebUSB, but try clearing browser cache/cookies.

**Q: Can I use the printer via Bluetooth instead?**
A: XP-58 with USB connection requires WebUSB. For Bluetooth, use different printer model.

**Q: Does it work on mobile (Android/iOS)?**
A: Not currently. USB printing requires a computer with Chrome/Edge browser.

**Q: What if I use a network printer instead?**
A: Change connection type to "Network" in printer settings.

**Q: Can I use multiple USB printers?**
A: Yes, select which one to use in "Pair USB Printer" step.

---

## Support

If issues persist after following this guide:
1. Collect error messages
2. Note browser version (F12 → Console)
3. Check device connections
4. Contact support with:
   - Exact error message
   - Browser type/version
   - Printer model
   - Connection method

---

## Summary Checklist

- [ ] Using Chrome or Edge browser
- [ ] Connected via HTTPS (not HTTP, except localhost)
- [ ] XP-58 printer powered on
- [ ] USB cable connected to computer
- [ ] Printer paired in app settings
- [ ] Test print successful
- [ ] Receipts printing correctly

**Status**: ✓ All checks passed = Printer ready to use!
