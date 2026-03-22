# Web PDF and Image Sharing/Export Enhancement

## Overview
Enhanced web platform support for exporting and sharing PDF receipts and receipt images. Users can now download, preview, and share receipts directly from web browsers with an improved user experience.

## New Features

### 1. Web Share Service (`web_share_service.dart`)
A comprehensive service providing web-specific file sharing and export functionality.

**Location**: `lib/services/web_share_service.dart`

**Features**:
- Browser download of PDF, images, CSV, and JSON files
- Preview in new browser tab
- Clipboard operations
- Native Web Share API support (if available)
- Custom download dialog with options

#### Key Methods:

```dart
// Download files
WebShareService.downloadPdf(bytes: pdfBytes, filename: 'receipt.pdf');
WebShareService.downloadImage(bytes: imageBytes, filename: 'receipt.png');
WebShareService.downloadCsv(content: csvString, filename: 'data.csv');
WebShareService.downloadJson(content: jsonString, filename: 'data.json');

// Preview files
WebShareService.previewPdf(bytes: pdfBytes, filename: 'receipt.pdf');
WebShareService.previewImage(bytes: imageBytes, filename: 'receipt.png');

// Clipboard
await WebShareService.copyToClipboard(text);
final text = await WebShareService.getFromClipboard();

// Download dialog
WebShareService.showDownloadDialog(
  filename: 'receipt.pdf',
  fileType: 'PDF',
  onDownload: () => print('Download clicked'),
  onPreview: () => print('Preview clicked'),
);
```

### 2. Receipt Screen Enhancement (`receipt_screen.dart`)
Updated to detect web platform and provide appropriate sharing options.

**Changes**:
- Import of `WebShareService`
- Web-specific logic in `_shareReceiptAsImage()`
- Web-specific logic in `_exportReceiptAsPdf()`

**Behavior on Web**:
1. User clicks "Share as Image" or "Export as PDF"
2. Dialog appears with "Download", "Preview", and "Cancel" buttons
3. Download: Triggers browser download
4. Preview: Opens file in new browser tab

**Behavior on Mobile**:
- Uses native share sheets (unchanged)
- Share via WhatsApp, Email, etc.

### 3. Receipt Detail Screen Enhancement (`receipt_detail_screen.dart`)
Similar enhancements to `_generateAndSharePDF()` and `_shareAsImage()` methods.

**Added Web Support**:
- Download dialog for PDF exports
- Download dialog for image exports
- Preview functionality for both file types

## User Experience

### Web Desktop/Laptop Users
1. **Share as Image Button**:
   - Captures receipt as PNG
   - Dialog: "Download" | "Preview" | "Cancel"
   - Download: Saves to Downloads folder
   - Preview: Opens PNG in new tab for viewing/saving

2. **Export as PDF Button**:
   - Generates receipt PDF with all details
   - Dialog: "Download" | "Preview" | "Cancel"
   - Download: Saves to Downloads folder
   - Preview: Opens PDF in browser viewer

3. **Share Button**:
   - Opens native share sheet (if supported)
   - Falls back to other options

### Mobile Users
- Unchanged behavior (native share sheets)
- Works on iOS, Android, and mobile web

## Technical Details

### File Type Support
```
PDF      -> application/pdf
PNG      -> image/png
CSV      -> text/csv;charset=utf-8
JSON     -> application/json;charset=utf-8
```

### Browser Compatibility
- Modern browsers (Chrome, Firefox, Safari, Edge)
- Uses Blob API for memory-efficient file handling
- Cleanup: Automatic URL revocation after download
- Fallback: Opens file in new tab if download fails

### Dialog Styling
- Modal overlay with semi-transparent backdrop
- Centered, responsive design
- Three action buttons: Download, Preview, Cancel
- System font stack for consistency

## Implementation Details

### Download Flow
1. Generate file bytes/content
2. Create Blob from bytes with appropriate MIME type
3. Create Object URL from Blob
4. Create and trigger anchor download
5. Cleanup: Remove anchor and revoke URL

### Preview Flow
1. Generate file bytes/content
2. Create Blob from bytes
3. Create Object URL
4. Open in new browser tab
5. Browser handles rendering (PDF viewer, image viewer, etc.)

### Clipboard Operations
- Uses Web Clipboard API
- Handles text copy/paste
- Graceful degradation for unsupported browsers

## Configuration

No configuration needed. The service automatically detects the platform using `kIsWeb` and behaves accordingly.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/web_share_service.dart';

if (kIsWeb) {
  // Use WebShareService
} else {
  // Use native sharing
}
```

## Error Handling

All methods include try-catch blocks:
- Invalid MIME types: Falls back to generic application type
- Clipboard access denied: Returns false gracefully
- Browser compatibility issues: Downloads still work via fallback
- Memory issues: Urls are revoked after short delay

## Testing

### Web Testing Checklist
- [ ] Download PDF receipt
- [ ] Preview PDF in new tab
- [ ] Download receipt image
- [ ] Preview image in new tab
- [ ] Dialog appears for both options
- [ ] Cancel button closes dialog
- [ ] File naming is correct
- [ ] Multiple downloads work sequentially

### Mobile Testing Checklist
- [ ] Share sheet appears on mobile
- [ ] Share to WhatsApp works
- [ ] Share to Email works
- [ ] Native behavior unchanged

## Future Enhancements

1. **Batch Export**: Download multiple receipts as ZIP
2. **Email Integration**: Send files via email without native dialog
3. **Cloud Storage**: Upload to Google Drive, Dropbox, etc.
4. **QR Code**: Generate shareable QR for receipt URLs
5. **Print Dialog**: Custom print preview before printing
6. **File Encryption**: Option to encrypt sensitive PDFs

## Integration Points

### Receipt Screen
- Location: `lib/presentation/sales/screens/receipt_screen.dart`
- Methods: `_shareReceiptAsImage()`, `_exportReceiptAsPdf()`
- Trigger: AppBar action buttons

### Receipt Detail Screen
- Location: `lib/presentation/sales/screens/receipt_detail_screen.dart`
- Methods: `_generateAndSharePDF()`, `_shareAsImage()`
- Trigger: Action buttons in sheet

### Other Screens Using PDF Export
- `export_report_screen.dart`: Financial reports
- `post_sale_action_sheet.dart`: Quick receipt actions
- Any screen using `PdfReceiptGenerator`

## Files Modified

1. **New File**:
   - `lib/services/web_share_service.dart` (150 lines)

2. **Updated Files**:
   - `lib/presentation/sales/screens/receipt_screen.dart`
     - Added import: `web_share_service.dart`
     - Enhanced: `_shareReceiptAsImage()` (50 lines)
     - Enhanced: `_exportReceiptAsPdf()` (80 lines)

   - `lib/presentation/sales/screens/receipt_detail_screen.dart`
     - Added import: `web_share_service.dart`
     - Enhanced: `_generateAndSharePDF()` (35 lines)
     - Enhanced: `_shareAsImage()` (45 lines)

## Code Examples

### Basic Usage
```dart
// Export PDF on web
if (kIsWeb) {
  WebShareService.downloadPdf(
    bytes: pdfBytes,
    filename: 'receipt_${saleId}.pdf',
  );
} else {
  // Mobile native share
  Share.shareXFiles([XFile(filePath)]);
}
```

### With Dialog
```dart
WebShareService.showDownloadDialog(
  filename: 'receipt.pdf',
  fileType: 'PDF',
  onDownload: () {
    WebShareService.downloadPdf(bytes: bytes, filename: 'receipt.pdf');
  },
  onPreview: () {
    WebShareService.previewPdf(bytes: bytes, filename: 'receipt.pdf');
  },
);
```

### Clipboard
```dart
// Copy receipt text
final copied = await WebShareService.copyToClipboard(receiptText);
if (copied) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Copied to clipboard')),
  );
}
```

## Browser Support Matrix

| Browser | PDF Download | Image Download | Preview | Clipboard |
|---------|-------------|----------------|---------|-----------|
| Chrome  | ✅          | ✅             | ✅      | ✅        |
| Firefox | ✅          | ✅             | ✅      | ✅        |
| Safari  | ✅          | ✅             | ✅      | ✅        |
| Edge    | ✅          | ✅             | ✅      | ✅        |
| IE 11   | ⚠️ Fallback | ⚠️ Fallback    | ⚠️      | ❌        |

✅ = Full support
⚠️ = Partial support (fallback works)
❌ = Not supported

## Performance Notes

- File download is memory-efficient (uses Blob API)
- URLs are automatically revoked after download
- No temporary file creation on web
- Large files (>100MB) may have browser limitations
- Image preview uses browser's native image viewer
- PDF preview uses browser's PDF.js or native viewer

## Security Considerations

- All operations are client-side (no server upload)
- Files are temporary Blob URLs (expire after use)
- Clipboard access requires user interaction
- No sensitive data is sent to external services
- MIME types are properly set for file type safety
