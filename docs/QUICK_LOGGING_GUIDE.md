# Quick Start: Capture Payment Error Logs

## Step 1: Prepare Terminal Windows

Open 3 terminal windows in PowerShell:

### Terminal 1: Run the App
```powershell
cd C:\Users\DELL\Desktop\mc
flutter clean
flutter run
```

### Terminal 2: Monitor Logs (KEEP THIS OPEN)
```powershell
cd C:\Users\DELL\Desktop\mc
flutter logs
```

**Leave this window open - it shows REAL-TIME logs!**

### Terminal 3: Save Logs to File (Optional)
```powershell
cd C:\Users\DELL\Desktop\mc
flutter logs > payment_logs.txt
```

## Step 2: Trigger Payment Error

1. Open the app in Terminal 1
2. Navigate to **Subscription Payment Screen**
3. Select a plan
4. Tap **"Subscribe Now"** button

## Step 3: Watch Terminal 2 for Logs

You should see logs like:

```
[SubscriptionPaymentScreen] ◆ Payment flow started
[FlutterwavePaymentService] Public key fetched from Firestore
[FlutterwavePaymentService] Flutterwave instance created successfully
[FlutterwavePaymentService] Initiating Flutterwave charge...
[FlutterwavePaymentService] Response received
[FlutterwavePaymentService] Success: false
[FlutterwavePaymentService] Status: error
```

## Step 4: Capture the Debug Info

**On the app screen:**
- Tap the **"🔍 Debug Info"** button below Subscribe button
- A popup will show:
  - System Information
  - Network Status
  - Device Details
  
**Screenshot this popup** (Windows Key + Shift + S)

## Step 5: Collect All Information

**From Terminal 2 (flutter logs):**
1. Select all text (Ctrl + A)
2. Copy (Ctrl + C)
3. Paste into a text file: `logs.txt`

**From App Debug Popup:**
1. Select all (Ctrl + A)
2. Copy
3. Paste into: `debug_report.txt`

**From Android (if available):**
```powershell
adb logcat -d > android_logs.txt
```

## Step 6: Check Firestore Keys

1. Open Firebase Console: https://console.firebase.google.com
2. Select "manage-care" project
3. Go to Firestore
4. Find: `secure` → `secure` document
5. **Screenshot** the publicKey field
6. Verify it looks like:
   ```
   FLWPUBK_TEST-[40+ alphanumeric characters]
   ```

## Step 7: Create Support Report

Create a file named `PAYMENT_ERROR_REPORT.txt`:

```
═══════════════════════════════════════════════════════
PAYMENT ERROR REPORT
═══════════════════════════════════════════════════════

TIME REPORTED: [Current Date/Time]

WHAT HAPPENED:
[Describe exactly what you did and what happened]

EXPECTED BEHAVIOR:
[What should have happened instead]

═══════════════════════════════════════════════════════
CONSOLE LOGS (from Terminal 2)
═══════════════════════════════════════════════════════
[Paste all logs from flutter logs]

═══════════════════════════════════════════════════════
DEBUG REPORT (from 🔍 button)
═══════════════════════════════════════════════════════
[Paste entire debug popup]

═══════════════════════════════════════════════════════
FIRESTORE KEY STATUS
═══════════════════════════════════════════════════════
Public Key (first 30 chars): [Copy from Firestore]
Key appears complete: ✓ Yes / ✗ No
Key starts with FLWPUBK_TEST: ✓ Yes / ✗ No

═══════════════════════════════════════════════════════
DEVICE INFO
═══════════════════════════════════════════════════════
Device Type: [Emulator/Physical Device/etc]
Device Name: [e.g., "Android Emulator"]
OS Version: [e.g., "Android 11"]
App Version: [from About screen]

═══════════════════════════════════════════════════════
```

## Analyzing the Logs

### Look for These Key Lines:

**✓ Good - Payment Initiates Correctly:**
```
[FlutterwavePaymentService] Flutterwave instance created successfully
[FlutterwavePaymentService] Initiating Flutterwave charge...
```

**✓ Good - Dialog Shows (you'd see UI change in app):**
```
[Actual Flutterwave payment dialog appears in app]
```

**✗ Bad - Key Issue:**
```
[FlutterwavePaymentService] ERROR: Invalid public key format
```
→ Firestore key is wrong or truncated

**✗ Bad - Network/Connection Error:**
```
[FlutterwavePaymentService] ❌ EXCEPTION CAUGHT
[FlutterwavePaymentService] Exception Type: SocketException
```
→ Can't reach Flutterwave servers

**✗ Bad - Generic Error:**
```
[FlutterwavePaymentService] Response received
[FlutterwavePaymentService] Success: false
[FlutterwavePaymentService] Status: error
```
→ Flutterwave rejected the request (check account/keys)

## Most Important: The Exception Details

If you see:
```
[FlutterwavePaymentService] ❌ EXCEPTION CAUGHT
[FlutterwavePaymentService] Exception Type: PlatformException
[FlutterwavePaymentService] Exception Message: [ERROR MESSAGE HERE]
```

**Copy the Exception Message exactly** - this is the most important piece for debugging!

## Verify Network Connectivity

In the app, after seeing logs:
1. Tap the **"🔍 Debug Info"** button
2. Look for:
   ```
   ━━━━━━━ NETWORK STATUS ━━━━━━━
   Flutterwave API reachable [SUCCESS]
   ```

If it says "Cannot reach Flutterwave API: ❌", then:
- Check WiFi/internet connection
- Try different network
- Disable VPN if using one

## AutomatedDiagnostic Summary

All logs now include timestamps like:
```
[2025-12-07 14:30:45.123456] [FlutterwavePaymentService] [INFO] Message here
```

This helps track exactly when each step occurs.

## Next Steps After Collecting Logs

1. **Review error logs above** - can you identify the issue?
2. **Check Firestore keys** - are they complete and correct?
3. **Verify network** - can you reach Flutterwave?
4. **Share complete report** - if still stuck, share files from Step 5

## Files to Share With Support

When asking for help, share:
- ✓ `logs.txt` (from flutter logs)
- ✓ `debug_report.txt` (from 🔍 button)
- ✓ `android_logs.txt` (from adb logcat, if Android)
- ✓ `PAYMENT_ERROR_REPORT.txt` (from Step 7)
- ✓ Screenshots of:
  - Firestore `secure/secure` document
  - Error message in app
  - Debug popup

---

**Pro Tip:** Keep terminal window with `flutter logs` running continuously during testing. As soon as an error occurs, scroll up to see the complete error trail!

---

Last Updated: December 7, 2025
Version: 1.0

