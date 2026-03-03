# XP-58 USB Printer - Technical Implementation

## Overview

The Manage Care application now supports WebUSB for printing to USB thermal printers like the Xprinter XP-58. This document explains the implementation and architecture.

## Architecture

### Components

```
┌─────────────────────────────────────────┐
│   Printer Settings Screen               │
│   (UI for pairing and testing)          │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│   UsbPrinterService                     │
│   (Core USB printing logic)             │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│   WebUsbPrinter (Web implementation)    │
│   (WebUSB API bridge)                   │
└──────────────┬──────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│   Browser WebUSB API                    │
│   (Chrome/Edge native support)          │
└─────────────────────────────────────────┘
```

### File Structure

```
lib/services/
├── usb_printer_service.dart              ← Main USB printer service
├── web_usb_printer.dart                  ← Conditional export
├── web_usb_printer_web.dart              ← Web implementation (JS interop)
├── web_usb_printer_stub.dart             ← Stub for non-web platforms
├── printer_service.dart                  ← Legacy printer service
└── thermal_printer_service.dart          ← Bluetooth thermal printer support

lib/providers/
└── settings_provider.dart                ← Stores printer configuration

lib/presentation/settings/screens/
└── printer_settings_screen.dart          ← UI for printer configuration
```

## Key Features Implemented

### 1. Device Pairing
- Browser prompts user to select USB printer
- Handles "NotAllowedError" (permission denied)
- Stores device ID for future use
- Lists previously paired devices

### 2. Error Recovery
- **Automatic retries** with configurable delay
- **Intelligent error messages** for different failure types
- **Permission re-granting** for access denied scenarios
- **Graceful degradation** when WebUSB unavailable

### 3. Retry Logic
```dart
for (int attempt = 0; attempt < retries; attempt++) {
  try {
    return await WebUsbPrinter.sendTextAsEscPos(...);
  } catch (e) {
    if (isRetryable(e) && attempt < retries - 1) {
      await Future.delayed(retryDelay);
      continue;
    }
    throw;
  }
}
```

### 4. Error Categorization

| Error | Cause | Solution |
|-------|-------|----------|
| NotAllowedError | Permission denied | Re-pair printer |
| Device not found | USB unplugged | Reconnect USB |
| TRANSFER_ERROR | Communication failure | Restart printer |
| WebUSB unavailable | Browser/HTTPS issue | Use Chrome/HTTPS |

---

## Code Implementation

### UsbPrinterService

**Key Methods**:

1. **requestPrinter(filters)**
   - Opens browser device picker
   - Requires user gesture (click)
   - Returns device info: `{deviceId, productName, vendorId, productId}`

2. **listDevices()**
   - Returns previously paired devices
   - May be empty if no devices paired yet
   - Non-blocking, safe to call anytime

3. **sendText(deviceId, text, retries)**
   - Converts text to ESC/POS format via WebUSB
   - Retries on transient failures
   - Returns bytes sent

4. **sendBytes(deviceId, bytes, retries)**
   - Sends raw ESC/POS bytes
   - For pre-formatted receipt data

5. **closePrinter(deviceId)**
   - Gracefully closes connection
   - Not always necessary but recommended

### Example Usage

```dart
// Pair printer (requires user click)
try {
  final device = await UsbPrinterService.requestPrinter();
  final deviceId = device['deviceId'] as String?;
  
  // Save device ID for later
  await settings.updatePrinterSettings(
    businessId,
    userId,
    selectedUsbDeviceId: deviceId,
  );
} catch (e) {
  print('Pairing failed: ${UsbPrinterService.getDetailedErrorMessage(e)}');
}

// Print receipt
try {
  final sent = await UsbPrinterService.sendText(
    deviceId: savedDeviceId,
    text: receiptText,
    retries: 2,
  );
  print('Sent $sent bytes');
} catch (e) {
  print('Print failed: ${UsbPrinterService.getDetailedErrorMessage(e)}');
}
```

---

## WebUSB Protocol

### ESC/POS Format
The XP-58 uses ESC/POS (Epson Standard Code for POS) protocol:

```
ESC @ = Initialize printer
ESC E {0|1} = Emphasis on/off
ESC d {n} = Print and feed n lines
ESC a {0|1|2} = Alignment (left/center/right)
ESC t {n} = Code table selection
GS ! {n} = Character size
```

### Text to ESC/POS Conversion
- Handled by `WebUsbPrinter.textToEscPosBase64()`
- Returns Base64-encoded ESC/POS bytes
- Sent to printer via `sendToPrinter(deviceId, base64)`

### Example Receipt ESC/POS
```
ESC @ (initialize)
ESC a 1 (center)
MANAGE CARE TEST\n
ESC a 0 (left)
Date: ...\n
Device: ...\n
ESC d 3 (feed 3 lines)
```

---

## Browser WebUSB API

### Permission Model

1. **No permission by default**: User must explicitly grant access
2. **User gesture required**: Must click button to open picker
3. **Device specific**: Permission is per-device, not global
4. **Browser-managed**: Shown in Settings → Content → USB Devices

### Supported Browsers

| Browser | Version | Support |
|---------|---------|---------|
| Chrome | 61+ | ✓ Full |
| Edge | 79+ | ✓ Full |
| Opera | 48+ | ✓ Full |
| Firefox | All | ✗ No |
| Safari | All | ✗ No |

### WebUSB Requirements

- **HTTPS required** (or localhost for development)
- **HTTP connections blocked** (security policy)
- **Incognito mode** blocks WebUSB (privacy)
- **Desktop only** (mobile WebUSB limited)

---

## Error Handling Strategy

### Error Types

1. **Permission Errors** (NotAllowedError)
   - User denied permission
   - Permission was revoked
   - **Action**: Re-grant permission by pairing again

2. **Device Errors** (Device not found)
   - USB cable disconnected
   - Device was removed
   - **Action**: Reconnect device, try again

3. **Communication Errors** (TRANSFER_ERROR)
   - Printer didn't respond
   - USB protocol error
   - **Action**: Restart printer, retry with backoff

4. **Environment Errors** (WebUSB not available)
   - Wrong browser
   - HTTP instead of HTTPS
   - Incognito mode
   - **Action**: Use Chrome/Edge on HTTPS

### Error Recovery

```dart
// Automatic retry on transient errors
final sent = await UsbPrinterService.sendText(
  deviceId: deviceId,
  text: text,
  retries: 2,  // Try up to 2 times
  retryDelay: Duration(milliseconds: 500),  // 500ms between retries
);

// Specific error handling
try {
  await UsbPrinterService.sendText(deviceId: id, text: text);
} catch (e) {
  if (e.toString().contains('Access Denied')) {
    // Ask user to re-pair
    showDialog('Please pair printer again');
  } else if (e.toString().contains('Device not found')) {
    // Ask to reconnect USB
    showDialog('Please reconnect printer');
  }
}
```

---

## Testing

### Test Printer Function

The app includes a "Test USB Printer" button in settings:

1. If no device selected, prompts user to select one
2. Sends test receipt with:
   - Header: "MANAGE CARE - TEST PRINT"
   - Current date/time
   - Device information
   - Footer: "Thank you!"
3. Prints multiple line feeds for paper advancement
4. Shows success/error message

### Manual Testing

```dart
// Test 1: Check WebUSB available
assert(WebUsbPrinter.available);

// Test 2: List devices
final devices = await UsbPrinterService.listDevices();
print('Found ${devices.length} devices');

// Test 3: Request printer
final device = await UsbPrinterService.requestPrinter();

// Test 4: Send text
final sent = await UsbPrinterService.sendText(
  deviceId: device['deviceId'],
  text: 'TEST\n\n\n',
);
print('Sent $sent bytes');
```

---

## Debugging

### Browser Console (F12)

Look for logs like:
```javascript
UsbPrinterService: Attempt 1/2 failed: NotAllowedError: ...
UsbPrinterService: Unable to list devices: WebUSB not available
```

### Check WebUSB Support

```javascript
// In browser console
navigator.usb ? "Supported" : "Not supported"
```

### Device Information

```javascript
// In browser console
navigator.usb.getDevices().then(devices => {
  console.log(devices);
});
```

---

## Performance Considerations

### Response Times
- Device listing: 50-100ms (usually instant)
- Device selection (picker): User-dependent (5-30s)
- Text to ESC/POS: 10-50ms
- USB transfer: Depends on text size
  - Test page: 200-500ms
  - Receipt: 500ms-2s

### Optimization Techniques
1. **Caching device ID**: Store in SharedPreferences
2. **Pre-formatting receipts**: Convert to ESC/POS in advance
3. **Batch printing**: Send multiple receipts in one transfer
4. **Asynchronous operations**: Never block UI thread

---

## Security Considerations

### Permission Model
- User must explicitly grant USB access
- Permissions are device-specific
- User can revoke anytime in browser settings
- No background access (requires user gesture)

### Data Privacy
- Receipt data is only sent to printer
- Data not transmitted over network
- Local browser memory only

### Potential Issues
- Malicious sites could request USB access
- User should carefully review device picker
- Browser sandboxing prevents arbitrary access

---

## Future Improvements

### Planned
- [ ] Support for other printer types (Bluetooth, Network)
- [ ] Multiple printer support
- [ ] Print queue management
- [ ] Offline print caching
- [ ] Receipt history/reprints

### Technical Debt
- [ ] Move hardcoded paper width to settings
- [ ] Add print job progress indicator
- [ ] Implement print job cancellation
- [ ] Better ESC/POS support

---

## References

- [WebUSB MDN Documentation](https://developer.mozilla.org/en-US/docs/Web/API/USB)
- [WebUSB Specification](https://wicg.github.io/webusb/)
- [ESC/POS Specification](https://en.wikipedia.org/wiki/ESC/P)
- [XP-58 Manual](https://xprinter.com)
- [Chrome USB API Samples](https://github.com/GoogleChromeLabs/web-usb)

