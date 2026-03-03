# Thermal Printer Troubleshooting Guide

## Issue: "Print failed" or "Cannot connect to printer"

### Symptoms
```
I/flutter (18615): [ThermalPrinter] [DEBUG] Attempt 1/3: Connecting to printer 86:67:7A:76:77:40
I/flutter (18615): result status connect: false
I/flutter (18615): [ThermalPrinter] [DEBUG] Attempt 2/3: Connecting to printer 86:67:7A:76:77:40
I/flutter (18615): result status connect: false
I/flutter (18615): [ThermalPrinter] [WARN] Could not connect to printer after 3 attempts
```

The app finds the printer but cannot establish a connection.

---

## Root Causes & Solutions

### 1. **Printer Power/Pairing Status** ⚡ (Most Common)

**Check:**
- [ ] Printer is turned ON
- [ ] Printer Bluetooth is in pairing mode (usually a button hold for 3-5 seconds)
- [ ] Printer is showing as "Available" or "Discoverable" in its display panel
- [ ] Printer isn't already connected to another device

**Fix:**
1. Power on the thermal printer
2. Hold the Bluetooth button (usually on back) for 5+ seconds until indicator blinks
3. Check printer display shows "Pairing mode" or similar
4. Go back to app and retry print

---

### 2. **Android Runtime Permissions** 🔐 (Android 12+)

**Check:**
- [ ] Bluetooth permissions were granted when prompted
- [ ] Location permission is granted (required for Bluetooth discovery)

**Verify in App:**
1. Open device Settings > Apps > Manage Care
2. Go to Permissions
3. Check: Bluetooth (Connected devices) ✓
4. Check: Bluetooth (Scan) ✓
5. Check: Location (Precise) ✓

**Fix if missing:**
1. In Manage Care app, try to print again
2. Accept all permission prompts
3. Retry printing

---

### 3. **Bluetooth Device Not Properly Paired** 🔗

**Check:**
1. Go to Android Settings > Bluetooth
2. Look for printer in "Paired Devices" list
3. Ensure it shows as paired (not just "Available")

**Fix:**
1. Remove printer from paired devices in Settings > Bluetooth
2. Delete it from Manage Care app's printer list (if stored)
3. Re-pair the printer:
   - Power on printer and enter pairing mode
   - In Android Bluetooth settings, tap "Pair new device"
   - Select your printer model (e.g., "RPP02N")
   - Confirm pairing
4. Return to app and retry

---

### 4. **Printer Connection Already Open** 🔄

**Issue:** Another app or previous app instance has the printer connection open

**Check:**
- App logs show `result status connect: false` consistently
- No timeout errors, just false returns

**Fix:**
1. Close Manage Care app completely (swipe from recent apps)
2. Power OFF the printer (wait 10 seconds)
3. Power ON the printer
4. Wait for Bluetooth to stabilize (10-15 seconds)
5. Open Manage Care and retry print

---

### 5. **Printer Out of Range or Disabled** 📡

**Check:**
- Printer Bluetooth range: Usually 10 meters/33 feet
- Device Bluetooth radio: Not turned off in airplane mode
- Printer antenna: Not blocked or damaged

**Fix:**
1. Move device closer to printer (within 5 meters)
2. Check device isn't in Airplane mode
3. Make sure device Bluetooth is enabled in quick settings
4. Power cycle both devices

---

## Detailed Diagnostic Flow

When you see "Cannot connect to printer" message in the app:

```
1. Permissions Check ✓
   ↓
2. Printer Discovery ✓ (Found RPP02N)
   ↓
3. Printer Test Connection ✗ (FAILS HERE)
   ↓
   → Printer is not responding to connection attempts
   → Likely cause: Power/Pairing issue
```

### Quick Diagnostic Steps

**In order of likelihood:**

1. **Verify Printer Power & Pairing** (90% of issues)
   ```
   Action: Check physical printer panel
   Look for: Blinking Bluetooth indicator
   Expected: "Pairing" or "Discoverable" mode
   ```

2. **Check Android Bluetooth Settings**
   ```
   Settings > Bluetooth
   Look for: Printer in "Paired Devices"
   If missing: Re-pair it
   ```

3. **Check App Permissions**
   ```
   Settings > Apps > Manage Care > Permissions
   Required: Bluetooth & Location = Allowed
   ```

4. **Power Cycle Everything**
   ```
   1. Close Manage Care app
   2. Turn OFF device Bluetooth (10 sec)
   3. Turn OFF printer (30 sec)
   4. Power ON printer
   5. Enable device Bluetooth
   6. Open Manage Care
   ```

5. **Clear Connection Cache** (Last Resort)
   ```
   Settings > Apps > Manage Care > Storage > Clear Cache
   Restart phone
   Re-pair printer in Bluetooth settings
   ```

---

## Log Analysis

### What Each Message Means

```
[ThermalPrinter] [INFO] Found 1 paired devices
→ ✓ Printer is recognized by Android
```

```
[ThermalPrinter] [DEBUG] Paired device: RPP02N (86:67:7A:76:77:40)
→ ✓ App can see the printer MAC address
```

```
[ThermalPrinter] [DEBUG] Attempt 1/3: Connecting to printer...
→ Trying to establish Bluetooth connection (3 retries)
```

```
result status connect: false
→ ✗ Connection failed
→ Cause: Usually printer not in pairing mode
```

```
[ThermalPrinter] [WARN] Could not connect after 3 attempts
→ All retry attempts exhausted
→ Need manual intervention (check printer)
```

---

## Advanced Solutions

### If Basic Troubleshooting Fails

**1. Check Printer Firmware**
- Printer manufacturer website
- Download latest firmware
- Update printer if available

**2. Test with Another Android App**
- Download "Bluetooth Terminal" app
- Try connecting to printer
- If it works: Issue is with Manage Care app
- If it fails: Issue is with printer/phone Bluetooth

**3. Printer Specific Notes**

**RPP02N (Realme printers):**
- [ ] Hold Bluetooth button 5+ seconds (not 3)
- [ ] Pairing mode lasts ~2 minutes
- [ ] Has separate power and Bluetooth buttons
- [ ] LED should blink when pairing

**Other Models:**
- Consult printer manual for pairing procedure
- Some printers need PIN code (usually 0000 or 1234)
- Some require longer pairing mode hold time

---

## When to Give Up (Accept Alternatives)

If after all steps above it still fails:

1. **Use Email Instead**
   - App can email receipt to customer
   - No printer needed

2. **Save Receipt**
   - Save to device storage
   - Print from another device later

3. **Consider Printer Replacement**
   - Bluetooth module may be faulty
   - Check if printer is on recall
   - Contact manufacturer support

---

## Code Implementation

### What the App Now Does

1. **Request Permissions** → Shows prompt if missing
2. **Test Connection** → Quick connectivity check before printing
3. **Retry Logic** → 3 attempts with 800ms delays
4. **Helpful Messages** → Tells user what to check

### Updated Error Messages

| Message | What to Check |
|---------|--------------|
| "Bluetooth permissions denied" | Grant permissions in Settings |
| "No printer configured" | Add printer in app settings |
| "Cannot connect to printer" | Power on & enable pairing mode |
| "Printer not responding" | Check device is powered |
| "Print failed" | Check printer has paper & ribbon |

---

## Support Information

For Manage Care App Support:
- Check app logs (enable debug logging in settings)
- Export logs and send to support
- Include: Phone model, Android version, Printer model

For Printer Support:
- Contact thermal printer manufacturer
- Check printer manual for pairing procedure
- Verify Bluetooth chipset is working

