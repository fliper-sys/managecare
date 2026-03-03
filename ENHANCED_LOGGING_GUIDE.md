# Enhanced Error Logging Guide for Flutterwave Payment

## Overview
This guide explains how to capture comprehensive error logs from your Manage Care app during payment processing, including device logs and Flutterwave-specific diagnostics.

## 1. Console Logs (Easy - No External Tools)

### Flutter Console Output
The app now logs detailed information to the console. Here's what you'll see:

**Startup Check:**
```
[FlutterwavePaymentService] Public key fetched from Firestore
[FlutterwavePaymentService] Key starts with: FLWPUBK_TEST-...
[FlutterwavePaymentService] Key length: 47
```

**Payment Initiation:**
```
[FlutterwaveLogger] Initiation Details:
  Public Key: FLWPUBK_TEST-81241a6...
  Currency: NGN
  Amount: 5000
  Email: user@example.com
  TxRef: SUB_userId_timestamp
  Test Mode: true
```

**Response Handling:**
```
[FlutterwavePaymentService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[FlutterwavePaymentService] Response received
[FlutterwavePaymentService] Success: false
[FlutterwavePaymentService] Status: error
[FlutterwavePaymentService] TxRef: {txRef_or_null}
[FlutterwavePaymentService] Full response object: {...}
[FlutterwavePaymentService] Response type: ChargeResponse
[FlutterwavePaymentService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Exception Logging (if error occurs):**
```
[FlutterwavePaymentService] ❌ EXCEPTION CAUGHT
[FlutterwavePaymentService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[FlutterwavePaymentService] Exception Type: PlatformException
[FlutterwavePaymentService] Exception Message: {error_details}
[FlutterwavePaymentService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[FlutterwavePaymentService] Full Stack Trace:
{complete_stack_trace_here}
[FlutterwavePaymentService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### How to View Console Logs

**In VS Code (if running on Android Emulator):**
```powershell
# Terminal window 1 - Start the emulator and app
flutter run

# Terminal window 2 - Watch the logs in real-time
flutter logs

# Or filter for Manage Care logs only
flutter logs | Select-String "Flutterwave|SubscriptionPayment|DeviceLogger"
```

**On Physical Android Device:**
```powershell
# Connect device and run
flutter run
flutter logs
```

**Copy-paste the entire console output when reporting issues!**

## 2. In-App Debug Button

A new **🔍 Debug Info** button appears on the subscription payment screen.

### Using the Debug Button

1. **Navigate to Subscription Payment Screen**
2. **Tap the "🔍 Debug Info (Tap to see logs)" button**
3. A popup will show:
   - System Information (platform, OS version)
   - Network connectivity status
   - Android native logs (if on Android)
   - Timestamps for debugging

### What the Debug Report Contains

```
═══════════════════════════════════════════════════════
FULL DEBUG REPORT
═══════════════════════════════════════════════════════
Timestamp: 2025-12-07 14:30:45.123456

━━━━━━━ SYSTEM INFO ━━━━━━━
platform: android
operatingSystemVersion: 11
isAndroid: true
isIOS: false
isWeb: false

━━━━━━━ NETWORK STATUS ━━━━━━━
Network test completed (see console logs above)

━━━━━━━ ANDROID NATIVE LOGS ━━━━━━━
{native_android_logs}

═══════════════════════════════════════════════════════
```

**Copy this entire report and share it with support!**

## 3. Android LogCat Logs (Advanced)

### Direct Android Device Logs

```powershell
# Get raw logcat output
adb logcat

# Filter for Flutterwave-related errors
adb logcat | Select-String "Flutterwave|WebView|payment|error"

# Save logcat to file for analysis
adb logcat > logcat_output.txt

# Get last 500 lines of logcat
adb logcat -d | tail -500
```

### What to Look For in LogCat

**WebView Loading Issues:**
```
E/Chromium: [ERROR] WebView failed to load
E/WebViewFactory: No WebView installed
```

**Network Issues:**
```
E/Network: Failed to connect to api.flutterwave.com
```

**JavaScript Errors (in WebView):**
```
E/AndroidWebKit: [ERROR] JavaScript error in Flutterwave
```

## 4. Firestore Credential Verification

### Check Your Keys in Firestore

1. **Open Firebase Console** → https://console.firebase.google.com
2. **Select your "manage-care" project**
3. **Go to Firestore Database**
4. **Navigate to:** `secure` → `secure` document
5. **Verify these fields exist:**
   - `publicKey`: Must start with `FLWPUBK_TEST` or `FLWPUBK_LIVE`
   - `secretKey`: Your Flutterwave secret key
   - Both keys must be **complete** (not truncated)

**Example Valid Key:**
```
FLWPUBK_TEST-81241a6c8f7e9b3a2d5c4e1f0a9b8c7d6e
```

**Invalid Examples:**
```
FLWPUBK_TEST    (truncated)
FLWPUBK_TEST-81241a6c8f7  (incomplete)
FLWPUBK_TEST-... (placeholder)
```

### Fix: Update Keys in Firestore

1. Get your keys from Flutterwave dashboard: https://app.flutterwave.com
2. Open Firestore Console
3. Click `secure` document
4. Edit `publicKey` field → Paste full key
5. Save changes
6. Restart the app

## 5. Flutterwave Account Verification

### Check Your Flutterwave Test Account

1. **Login to:** https://app.flutterwave.com
2. **Settings → API Keys**
   - Copy your **Test Public Key** (starts with `FLWPUBK_TEST`)
   - Copy your **Test Secret Key**
3. **Check Account Status:**
   - Settings → Account → Verify account status is "Active"
   - Make sure "Test Mode" is enabled
4. **Check Payment Methods:**
   - Settings → Payment Methods
   - Verify test methods are enabled:
     - ✓ Test Cards
     - ✓ Test USSD
     - ✓ Test Bank Transfer

### Enable Test Mode

1. In Flutterwave dashboard, top-right corner
2. Toggle "Test Mode" to **ON** (if available)
3. Confirm you see test data

## 6. Network Connectivity Check

### Verify You Can Reach Flutterwave

```powershell
# Test connection to Flutterwave
Test-NetConnection -ComputerName api.flutterwave.com -Port 443

# If on device, use the built-in network check
# The debug button will show network status automatically
```

### Symptoms of Network Issues

- `connection timeout`
- `Failed to connect`
- `DNS resolution failed`
- `Certificate validation error`

**Fix:**
- Check internet connection is active
- Try on WiFi (not cellular)
- Disable VPN if using one
- Check firewall/proxy settings

## 7. Gathering Information for Support

### Complete Diagnostic Package

When reporting payment issues, collect:

**1. Console Output:**
```
flutter logs > console_logs.txt
```

**2. Debug Report:**
- Tap "🔍 Debug Info" button
- Copy entire popup
- Paste to text file

**3. Android LogCat (if on Android):**
```
adb logcat -d > logcat.txt
```

**4. Firestore Keys:**
- Screenshot of `secure/secure` document
- Confirm keys are visible (not truncated)

**5. Flutterwave Account Info:**
- Screenshot of API Keys page
- Screenshot of Account Status

**6. Device Info:**
- Device name (e.g., "Samsung Galaxy S10")
- Android/iOS version
- App version (from About screen)

### Report Template

```
PAYMENT FAILURE REPORT
═══════════════════════════════════════════════════════

ISSUE:
[Describe what happened]

STEPS TO REPRODUCE:
1. [Step 1]
2. [Step 2]
3. [Step 3]

DEVICE INFO:
- Device: [e.g., Android Emulator]
- OS Version: [e.g., Android 11]
- App Version: [version]

FLUTTERWAVE KEYS:
- Public Key (first 20 chars): FLWPUBK_TEST-812...
- Key Status: ✓ Complete / ✗ Truncated
- Account Status: Active / Pending / Unknown

CONSOLE LOGS:
[Paste complete flutter logs output]

DEBUG REPORT:
[Paste entire debug info popup]

LOGCAT (if Android):
[Paste relevant lines from adb logcat]

ERROR MESSAGE:
[Copy exact error message from app]

═══════════════════════════════════════════════════════
```

## 8. What Each Log Section Means

### Public Key Validation
```
[FlutterwavePaymentService] Key starts with: FLWPUBK_TEST-81241a6...
[FlutterwavePaymentService] Key length: 47
```
✓ **Good**: Starts with FLWPUBK and has proper length
✗ **Bad**: Truncated, missing prefix, or wrong length

### Flutterwave Instance Creation
```
[FlutterwavePaymentService] Flutterwave instance created successfully
```
✓ **Good**: Instance created without errors
✗ **Bad**: Would show exception before this line

### Charge Response
```
[FlutterwavePaymentService] Response received
[FlutterwavePaymentService] Success: false
[FlutterwavePaymentService] Status: error
```
✓ **Good**: `Success: true` and `Status: completed`
✗ **Bad**: `Success: false` or `Status: error/cancelled`

### Exception Caught
```
[FlutterwavePaymentService] ❌ EXCEPTION CAUGHT
[FlutterwavePaymentService] Exception Type: PlatformException
```
✗ **Always Bad**: An exception occurred during payment processing

## 9. Common Issues & Solutions

### Issue 1: "No response from Flutterwave"
**Logs show:**
```
[FlutterwavePaymentService] Initiating Flutterwave charge...
[waits 30+ seconds]
[FlutterwavePaymentService] ❌ EXCEPTION CAUGHT
```

**Solutions:**
1. Check internet connection
2. Verify Firestore keys are not truncated
3. Try on different network (WiFi vs cellular)
4. Check if Flutterwave servers are up: https://status.flutterwave.com

### Issue 2: "Invalid key format"
**Logs show:**
```
[FlutterwavePaymentService] ERROR: Invalid public key format
```

**Solutions:**
1. Verify key in Firestore starts with `FLWPUBK`
2. Regenerate keys in Flutterwave dashboard
3. Copy-paste carefully (watch for spaces or line breaks)
4. Check key is not wrapped or truncated

### Issue 3: "WebView error on Android"
**Logs show:**
```
E/Chromium: [ERROR] WebView failed to load
```

**Solutions:**
1. Update Android WebView: Settings → Google Play → Search "Android System WebView" → Update
2. Restart device
3. Clear app cache: Settings → Apps → Manage Care → Storage → Clear Cache
4. Reinstall app: `flutter clean` then `flutter run`

### Issue 4: "Payment dialog closes immediately"
**Logs show:**
```
[FlutterwavePaymentService] Response received
[FlutterwavePaymentService] Status: cancelled
```

**Solutions:**
1. Check if Flutterwave account test mode is enabled
2. Verify payment methods are available in test account
3. Try different payment method
4. Check for JavaScript errors in logcat

## 10. Quick Troubleshooting Checklist

- [ ] Internet connection is active and stable
- [ ] Public key in Firestore starts with `FLWPUBK_TEST`
- [ ] Public key is NOT truncated (should be 40+ characters)
- [ ] Flutterwave test account is active
- [ ] Payment methods are enabled for test account
- [ ] Android WebView is installed and up-to-date (Android only)
- [ ] No VPN or proxy blocking payment gateway
- [ ] App has INTERNET permission in AndroidManifest.xml
- [ ] Device time/date is set correctly
- [ ] Firestore security rules allow reading from `secure/secure`

## 11. How to Share Logs for Support

**Email Support with:**
1. Device info (Device name, OS version)
2. Console logs (flutter logs output)
3. Debug report (from 🔍 button)
4. Steps to reproduce
5. Screenshots of error/issue

**Include the report template from Section 7!**

---

## Quick Reference: Essential Commands

```powershell
# Start app with log monitoring
flutter run
flutter logs

# Get Android system logs
adb logcat > logs.txt

# Clear app cache
flutter clean

# Restart emulator
adb emu kill

# Check Flutterwave connectivity
Test-NetConnection -ComputerName api.flutterwave.com -Port 443
```

---

**Questions? Check:**
- Flutterwave Docs: https://developer.flutterwave.com
- Flutter Logs: https://flutter.dev/docs/testing/debugging#logging
- Firebase Console: https://console.firebase.google.com

