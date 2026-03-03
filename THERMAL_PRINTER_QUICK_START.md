# Thermal Printer Setup & Connection Guide

## Quick Start

### Prerequisites
- ✓ Thermal printer (RPP02N, ESC/POS, or compatible)
- ✓ Printer paired in Android Bluetooth settings
- ✓ Printer powered on
- ✓ Manage Care app with printer support

---

## Step 1: Physical Printer Setup

### Power On
```
1. Locate power button (usually on back)
2. Press and hold until indicator light appears
3. Wait 30-45 seconds for printer to boot
```

### Enter Pairing Mode
```
1. Locate Bluetooth button (usually on back, labeled BT)
2. Hold for 5+ seconds (NOT 3 seconds)
3. Listen for: Beep or double-beep sound
4. Look for: Blinking Bluetooth indicator on printer
5. Printer display: Should show "Pairing" or "Discoverable"
6. Pairing mode lasts ~2 minutes
```

---

## Step 2: Android Device Setup

### Add Printer to Bluetooth

**Path:** Settings → Bluetooth

1. Turn ON Bluetooth (toggle in quick settings)
2. Wait 3-5 seconds for scan to start
3. Look for printer name in "Available Devices"
   - Example: "RPP02N", "RONGTA", "XPRINTER", etc.
4. Tap printer name to pair
5. Confirm pairing if prompted
6. Should appear in "Paired Devices" list

### Grant App Permissions

**Path:** Settings → Apps → Manage Care → Permissions

Required permissions:
- ✓ Bluetooth (Connected devices)
- ✓ Bluetooth (Scan)
- ✓ Location (Precise location)
- ✓ Nearby devices

If any show "Not granted":
1. Tap permission name
2. Select "Allow"
3. Return to Settings

---

## Step 3: Configure Printer in App

### In Manage Care App

1. Go to **Settings** (gear icon)
2. Find **Printer Settings** section
3. Tap **"Select Printer"** or **"Configure Printer"**
4. Choose your printer from list
   - Example: "RPP02N (86:67:7A:76:77:40)"
5. **Paper Width**: Select 80mm (most common)
6. **Test Print**: Tap to verify connection
   - Should print small test page
7. **Save Settings**

---

## Step 4: Test Print

### From Receipt Screen

1. Complete a sale/transaction
2. At checkout, tap **"Print"** button
3. App will:
   - Request Bluetooth permissions (if first time)
   - Test printer connection
   - Print receipt if successful
4. Look for: "Receipt printed!" message in green

### Expected Output

```
====== SWEET LIQUID LIMITED ======

Order: #12345
Date: 09/12/2025 03:45 PM

Item Name               Qty    Price
Whiskey                 1      $8.99
Beer                    2      $3.50 ea
Soda                    1      $1.50
                           ----------
Subtotal                       $17.99
Total                          $17.99

Payment: Cash

Thank You!
===================================
```

---

## Connection Workflow

```
┌─────────────────────────┐
│ Tap "Print" Button      │
└──────────┬──────────────┘
           ↓
┌─────────────────────────┐
│ Request Permissions     │ ← User taps "Allow"
└──────────┬──────────────┘
           ↓
┌─────────────────────────┐
│ Discover Printers       │ ← Finds paired devices
└──────────┬──────────────┘
           ↓
┌─────────────────────────┐
│ Test Connection         │ ← Verify printer responds
└──────────┬──────────────┘
           ↓
    ┌──────┴──────┐
    ↓             ↓
SUCCESS       FAILURE
    │             │
    ↓             ↓
  PRINT      ERROR MESSAGE
   ✓              ✗
```

---

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| "Bluetooth permissions denied" | Grant permissions in Settings > Apps > Manage Care > Permissions |
| "No printer found" | 1. Power on printer 2. Enter pairing mode 3. Add to Bluetooth in Settings |
| "Cannot connect to printer" | 1. Check printer power ON 2. Verify pairing mode ACTIVE 3. Move closer to phone |
| "Printer not responding" | 1. Power cycle printer (OFF 30s, then ON) 2. Re-enter pairing mode 3. Retry |
| "Print failed" | 1. Check paper level 2. Check ribbon/ink 3. Try test print from settings |

---

## Common Printer Models & Pairing

### RPP02N (Most Common)
- **Pairing Button:** Back of unit, labeled "BT"
- **Hold Time:** 5+ seconds (long press)
- **Indicator:** Blinking blue light
- **Sound:** Double beep when pairing
- **PIN:** Usually 0000

### RONGTA Series
- **Pairing Button:** Side or back, labeled "Connect" 
- **Hold Time:** 3-5 seconds
- **Indicator:** Green/blue blinking
- **Sound:** Single beep
- **PIN:** 1234 (if prompted)

### XPRINTER Series
- **Pairing Button:** Near power button
- **Hold Time:** 5+ seconds
- **Indicator:** Blinking light (color varies)
- **Sound:** Yes, confirmatory beep
- **PIN:** Usually 0000 or 1234

### Generic ESC/POS Thermal Printer
- Consult specific model manual
- Usually holds pairing button 3-5 seconds
- Most support PIN: 0000

---

## Android Version Specific Notes

### Android 12+ (Special Requirements)

**Why:** Google added stricter Bluetooth permission requirements

**Required Permissions:**
- BLUETOOTH_CONNECT (paired device access)
- BLUETOOTH_SCAN (device discovery)
- ACCESS_FINE_LOCATION (device location)

**In Manage Care:**
- App automatically requests these on first print
- User sees permission prompt
- User must tap "Allow" for each permission

**If Already Denied:**
1. Settings → Apps → Manage Care → Permissions
2. Enable: Bluetooth (Connected devices)
3. Enable: Bluetooth (Scan)
4. Enable: Location
5. Return to app and retry

### Android 11 and Below

- Only needs: ACCESS_FINE_LOCATION and BLUETOOTH
- Usually already granted in app manifest
- If issues, check Bluetooth is enabled in quick settings

---

## Advanced Configuration

### Paper Width Setting

**80mm** (Standard for most printers)
- Receipt width: ~3.15 inches
- Characters per line: ~32-42 depending on font

**58mm** (Smaller receipts)
- Receipt width: ~2.3 inches
- Characters per line: ~24-32

Choose based on:
1. Physical printer paper width
2. Receipt size preference
3. Font size preferences

### Default Printer Selection

If you have multiple printers:
1. In app, the last printer used becomes default
2. Or: Select in Settings > Printer Settings > Default Printer
3. When printing, app asks to confirm if multiple available

---

## Testing Connection

### In Settings (Test Print)
1. Settings → Printer Settings
2. Tap "Test Print" button
3. Should print verification page if connected

### Logs (For Debugging)
1. Settings → Advanced → Enable Debug Logging
2. Complete a print operation
3. Export logs
4. Share with support if needed

---

## When Connection Fails

### Immediately After Pairing

**Likely Cause:** Printer not in pairing mode anymore

**Fix:**
1. Go back to printer
2. Hold pairing button again (5+ seconds)
3. Return to phone immediately
4. Try print again before pairing mode times out

### After Printer Idle Time

**Likely Cause:** Connection was dropped (timeout)

**Fix:**
1. Turn off printer completely
2. Wait 30 seconds
3. Power on printer
4. Wait for boot (~45 sec)
5. Re-enter pairing mode
6. Retry print

### Intermittent Failures

**Likely Cause:** Bluetooth interference or range issue

**Fix:**
1. Move phone and printer closer (within 5 meters)
2. Check for interference sources:
   - Microwave ovens
   - WiFi routers
   - 2.4GHz wireless devices
3. Switch Bluetooth off and on on phone
4. Retry

---

## Getting Help

### In-App Support
1. Settings → Help & Support
2. Select "Thermal Printer Issues"
3. View FAQ and solutions

### Manual Pairing (If App Discovery Fails)
1. Settings → Bluetooth
2. Tap "Pair new device"
3. Wait for scan
4. Select printer manually
5. Confirm pairing

### Advanced: ADB Debugging
```bash
# Check Bluetooth permission status
adb shell pm list permissions | grep -i bluetooth

# Grant permissions manually
adb shell pm grant com.managecare android.permission.BLUETOOTH_CONNECT
adb shell pm grant com.managecare android.permission.BLUETOOTH_SCAN
```

---

## Verification Checklist

Before you print, verify:

- [ ] Printer is powered ON (light visible)
- [ ] Printer Bluetooth is in pairing mode (blinking indicator)
- [ ] Phone Bluetooth is ON (check quick settings)
- [ ] Printer appears in phone's Bluetooth settings as "Paired"
- [ ] Manage Care app has Bluetooth permissions granted
- [ ] Printer configured in app (Settings → Printer Settings)
- [ ] Paper loaded in printer
- [ ] Ribbon/ink present in printer (if applicable)

If all checked: Print should work immediately!

---

## Performance Notes

- **First Print:** May take 3-5 seconds (connection + setup)
- **Subsequent Prints:** Usually 1-2 seconds
- **Connection Test:** ~2 seconds
- **Paper Width Impact:** 80mm prints slightly faster than 58mm
- **Receipt Size Impact:** Longer receipts take proportionally longer

---

## Limitations & Workarounds

| Limitation | Workaround |
|-----------|-----------|
| Can't print after printer powered off | Power on printer, re-enter pairing, retry |
| Printer connects but won't print | Check paper loaded, power cycle both devices |
| Multiple printers in area causing issues | Keep distance from other Bluetooth printers |
| Printing very slow | Move closer to printer, reduce interference |
| Won't reconnect after long idle | Fully restart both printer and phone |

---

Last Updated: December 9, 2025

