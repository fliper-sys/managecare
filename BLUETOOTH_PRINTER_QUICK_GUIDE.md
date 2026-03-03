# Bluetooth Printer - Quick Troubleshooting Guide

## ✅ Working Correctly?

Test by completing a sale and clicking **Print Receipt**. Receipt should print within 5-10 seconds.

---

## 🔴 Common Issues & Fixes

### ❌ "No Bluetooth printer found. Pair a printer first."

**Cause**: No printers are paired with the device

**Fix**:
1. Go to phone/computer **Settings**
2. Open **Bluetooth** settings
3. Put printer in pairing mode
4. Pair the printer
5. Try printing again

---

### ❌ "Bluetooth permissions denied"

**Cause**: App doesn't have permission to use Bluetooth

**Fix** (Android):
1. Go to **Settings** → **Apps**
2. Find **Manage Care** app
3. Select **Permissions**
4. Enable **Bluetooth Connect** and **Bluetooth Scan**
5. Try printing

**Fix** (iOS):
1. Go to **Settings** → **Manage Care**
2. Enable **Bluetooth**
3. Try printing

---

### ❌ "Cannot reach printer. Power on & check pairing."

**Cause**: Printer is off or not responding

**Fix**:
1. **Check printer**:
   - Is it powered on?
   - Is Bluetooth enabled?
   - Is it in pairing mode?

2. **Restart printer**:
   - Turn off
   - Wait 10 seconds
   - Turn on

3. **Reconnect**:
   - Forget printer in Bluetooth settings
   - Power on printer
   - Put in pairing mode
   - Re-pair

4. **Try again**

---

### ❌ "Print failed. Check printer power & connection."

**Cause**: Printer lost connection during print or not responding

**Fix**:
1. Check USB/power cable is connected
2. Ensure paper is loaded
3. Restart printer
4. Try test print in Settings
5. If still failing, try again in 30 seconds

---

### ❌ Test print doesn't work in Settings

**Cause**: Printer connection issue

**Fix**:
1. Verify printer is on and paired
2. Wait 10 seconds after turning on
3. Check print head isn't jammed
4. Try different distance from printer
5. Restart app and try again

---

## ✅ Test Print Steps

1. Open app
2. Go to **Settings** → **Printer Settings**
3. Verify printer is selected
4. Click **Test Bluetooth Printer**
5. Receipt should print from printer
6. If works → Bluetooth printing ready

---

## 📱 Device-Specific Steps

### Android
1. **Settings** → **Connected devices** → **Bluetooth**
2. Put printer in pairing mode
3. Select printer from list
4. Confirm pairing
5. Grant permissions when prompted

### iOS
1. **Settings** → **Bluetooth**
2. Turn on Bluetooth
3. Put printer in pairing mode
4. Select printer from list
5. Grant permissions when prompted

### macOS
1. **System Preferences** → **Bluetooth**
2. Put printer in pairing mode
3. Click **Connect** next to printer
4. Confirm if prompted

### Windows
1. **Settings** → **Bluetooth & devices** → **Bluetooth**
2. Put printer in pairing mode
3. Click **Add device**
4. Select printer
5. Follow prompts

---

## 🔧 Quick Checklist

Before troubleshooting, verify:

- [ ] Printer is powered ON
- [ ] Printer has paper loaded
- [ ] Printer is paired (visible in Bluetooth settings)
- [ ] App has Bluetooth permission
- [ ] Phone/computer is within 10 meters
- [ ] No other app using printer

---

## 📊 Performance

| Task | Time |
|------|------|
| Discover printer | 2-5 sec |
| Connect | 3-5 sec |
| Send receipt | 2-3 sec |
| **Total** | **5-10 sec** |

If taking longer, check connection quality.

---

## 🆘 Still Failing?

1. **Restart everything**:
   - Close app
   - Turn off printer (10 sec)
   - Turn off Bluetooth on device
   - Turn on Bluetooth
   - Turn on printer
   - Open app

2. **Clear printer**:
   - Forget printer in Bluetooth
   - Re-pair printer

3. **Check System Logs**:
   - For Android: Android Studio Logcat
   - For iOS: Xcode Console
   - For Web: Browser Console (F12)

4. **Collect debug info**:
   - Screenshot of error
   - Printer model
   - Device type (Android/iOS/Windows)
   - App version
   - Contact support

---

## 📞 Support Info

When contacting support, provide:
- **Error message** (exact text)
- **Printer model** (e.g., XP-58)
- **Device type** (Android/iOS/Windows/Mac)
- **OS version**
- **App version**
- **What you tried** (steps taken)

---

## 🎯 When It Works

You'll see:
- ✅ "Scanning for printers..." (1-2 sec)
- ✅ "Connecting to printer..." (2-3 sec)
- ✅ "Printing receipt..." (2-3 sec)
- ✅ "✓ Receipt printed successfully!" (green message)
- 📄 Printer outputs receipt

---

## 💡 Pro Tips

1. **Keep printer nearby** during first use
2. **Test print regularly** to catch issues early
3. **Pair printer once** - stays paired
4. **Check paper** before printing
5. **Restart printer weekly** for best performance

---

**Status**: ✓ Guide Complete
