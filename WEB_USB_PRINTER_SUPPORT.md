# Web USB Thermal Printer Support (Manage Care)

Overview
- This project now supports printing receipts directly from the browser to a USB-connected thermal printer using the WebUSB API (Chrome/Edge only).

Browser & Security Requirements
- WebUSB is currently supported in Chromium-based browsers (Chrome, Edge).
- The page must be served over HTTPS or be on `localhost` (for development).
- Users must grant explicit permission when pairing the device via the browser device picker.

How it works
- A small JS helper (`web/js/web_usb_printer.js`) exposes a `window.webUsbPrinter` API to the web app.
- Flutter web code calls this API using JS interop (`lib/services/web_usb_printer_web.dart`) to request a device and send ESC/POS bytes.
- Receipts are encoded to a basic ESC/POS byte stream (`ESC @`, text, feed, cut) and transferred using `transferOut` or `controlTransferOut`.

Usage (end-user)
1. Open the app in Chrome/Edge on the POS machine.
2. Go to Settings → Printer Settings → set Connection Type to `USB`.
3. Click `Pair USB Printer` and select your thermal printer from the browser device picker.
4. Save settings and use `Test Print` to send a sample receipt.

Developer Notes
- The browser may require vendor/product filters for the device picker. If your printer does not appear, add its vendorId/productId in the request function or use a known list of vendorIds.
- Not all USB printers support `transferOut` with bulk OUT endpoints; the helper falls back to a class control transfer when necessary.
- Cutting the paper uses `GS V 0` (may not work on all printers).

Fallbacks
- If WebUSB is not available or user cannot pair, the web UI will fall back to generating a PDF for download for manual printing.
- For robust cross-browser support, consider running a small local bridge (node/native service) to accept print jobs from the web app (HTTP/WebSocket) and send to the USB printer.

Security & Privacy
- WebUSB only allows access after explicit user permission. The permission is remembered by the browser until revoked.

Files added/changed
- web/js/web_usb_printer.js — WebUSB helper
- lib/services/web_usb_printer_web.dart — Web implementation (conditional)
- lib/services/web_usb_printer_stub.dart — non-web stub
- lib/services/web_usb_printer.dart — conditional export
- lib/services/printer_service.dart — uses WebUSB printing when connectionType == 'usb' on web
- lib/presentation/settings/screens/printer_settings_screen.dart — UI for pairing USB printers and testing
- lib/providers/settings_provider.dart — added `selectedUsbDeviceId` storage

Limitations
- Browser compatibility is limited; this is tested on Chrome/Edge only.
- Some printers may require vendor-specific initialization or encoding (CP437, Latin1). Adjustments may be necessary for specific models.
