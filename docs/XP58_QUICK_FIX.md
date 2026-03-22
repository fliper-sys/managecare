# XP-58 USB Printer - Quick Troubleshooting Card

## 🔴 Access Denied Error

**Problem**: "USB Access Denied" or "Permission Denied"

**Quick Fix** (30 seconds):
1. Click "Pair USB Printer" again
2. Select printer when browser prompts
3. Grant permission if asked
4. Try printing again

---

## 🔴 Device Not Found Error

**Problem**: "Printer Disconnected" or "Device not found"

**Quick Fix** (1 minute):
1. Check USB cable is plugged in
2. Try different USB port
3. Power off printer, wait 10 sec, power on
4. Click "Refresh Devices"
5. Try printing

---

## 🔴 WebUSB Not Available

**Problem**: "WebUSB is not supported in this browser"

**Quick Fix** (2 minutes):
1. Close current browser
2. Open **Chrome** or **Edge** instead
3. Make sure URL is **HTTPS** (not HTTP)
4. Try pairing printer again

---

## 🔴 Communication Error

**Problem**: "USB Communication Error" or "Transfer Failed"

**Quick Fix** (2 minutes):
1. Restart printer (off 10 sec, back on)
2. Check USB cable quality
3. Try different USB port
4. Close and reopen app
5. Try "Test USB Printer"

---

## 🟡 No Devices Found

**Problem**: "No devices found" when clicking Refresh

**Quick Fix** (3 minutes):
1. Check printer power is ON
2. Check USB cable connection both ends
3. Try different USB port
4. Windows only: Install drivers from Xprinter website
5. Restart computer
6. Try again

---

## ✅ Testing Printer

**How to verify printer is working**:

1. Settings → Printer Settings
2. Click "Test USB Printer"
3. Printer should print test page
4. If it prints → USB connection OK
5. If error → Follow error above

---

## ⚙️ Setup Checklist

```
□ Using Chrome or Edge
□ On HTTPS (not HTTP)
□ Printer powered ON
□ USB cable plugged in
□ Clicked "Pair USB Printer"
□ Granted browser permission
□ Test print successful
```

---

## 🆘 Still Not Working?

1. **Restart everything**:
   - Close browser
   - Turn off printer (10 sec)
   - Turn on printer
   - Open browser again

2. **Clear permissions**:
   - Chrome: chrome://settings/content/usbDevices
   - Edge: edge://settings/content/usbDevices
   - Remove printer from list
   - Pair again

3. **Check Windows Device Manager**:
   - Search "Device Manager"
   - Look for Xprinter
   - If yellow icon, update drivers

4. **Try different USB port**:
   - Move USB cable to different port
   - Try front panel port if available

---

## Browser Check

**Chrome**: ✓ Works
**Edge**: ✓ Works  
**Firefox**: ✗ No WebUSB
**Safari**: ✗ No WebUSB
**HTTP**: ✗ WebUSB blocked (use HTTPS)
**Incognito**: ✗ WebUSB blocked

---

**Still failing?**
- Take screenshot of error
- Note exact error message
- Check browser console (F12)
- Contact support with screenshot + message
