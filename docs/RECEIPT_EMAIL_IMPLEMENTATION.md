# Receipt Email & PDF Implementation Guide

## Overview
This implementation provides complete receipt generation, email sending, and PDF sharing functionality for your checkout flow.

## Components

### 1. **PDF Receipt Generator** (`pdf_receipt_generator.dart`)
Generates professional PDF receipts with customizable layout.

**Features:**
- Supports 58mm (thermal) and 80mm (standard) paper widths
- Customizable header and footer
- Item-wise breakdown with quantities and prices
- Tax and total calculations
- Professional formatting

**Usage:**
```dart
final footerWithPowered = 'Thank you for shopping\nPowered by Manage Care';
final pdfFile = await PdfReceiptGenerator.generateReceiptPdf(
  businessName: 'Your Business',
  receiptNumber: 'REC001',
  receiptDate: DateTime.now(),
  items: [
    {'name': 'Item 1', 'quantity': 1, 'price': 5000},
  ],
  subtotal: 5000,
  tax: 500,
  total: 5500,
  paymentMethod: 'Cash',
  customerName: 'John Doe',
  customerEmail: 'john@example.com',
  customHeader: 'Welcome!',
  customFooter: footerWithPowered,
  paperWidth: '58', // or '80'
  cashier: 'Staff',
  poweredByText: footerWithPowered,
);
```

### 2. **Email Receipt Service** (`email_receipt_service.dart`)
Sends receipts via email using Firebase Cloud Functions.

**Features:**
- Upload PDF to Firebase Storage
- Send receipt email via Cloud Function
- Support for multiple recipients
- Delete receipt from storage

**Usage:**
```dart
final emailService = EmailReceiptService();
final success = await emailService.sendReceiptEmail(
  recipientEmail: 'customer@example.com',
  receiptNumber: 'REC001',
  businessName: 'Your Business',
  pdfFile: pdfFile,
  totalAmount: 5500,
  customerName: 'John Doe',
);
```

### 3. **Receipt Sharing Service** (`receipt_sharing_service.dart`)
Share receipts via native share dialog or specific apps.

**Features:**
- Share via native share dialog
- Direct WhatsApp sharing
- Email sharing
- Temporary file management

**Usage:**
```dart
await ReceiptSharingService.shareReceiptPdf(
  pdfFile: pdfFile,
  receiptNumber: 'REC001',
  context: context,
);
```

### 4. **Checkout Receipt Handler** (`checkout_receipt_handler.dart`)
Main handler that coordinates all receipt operations.

**Features:**
- Generates receipt number
- Creates PDF
- Shows confirmation dialog
- Sends email notification
- Notifies admin of payment

**Usage:**
```dart
await CheckoutReceiptHandler.handleCheckoutReceipt(
  context: context,
  businessName: 'Your Business',
  customerName: 'John Doe',
  customerEmail: 'john@example.com',
  items: cartItems,
  subtotal: 5000,
  tax: 500,
  total: 5500,
  paymentMethod: 'Card',
  customHeader: 'Welcome!',
  customFooter: 'Thank you!',
  paperWidth: '58',
  onComplete: (success) {
    if (success) {
      // Receipt sent/saved successfully
      print('Receipt handling complete');
    }
  },
);
```

## Integration Steps

### Step 1: Add Dependencies to pubspec.yaml
```yaml
dependencies:
  pdf: ^3.8.0
  path_provider: ^2.0.0
  share_plus: ^4.0.0
  cloud_functions: ^4.0.0
  firebase_storage: ^11.0.0
  intl: ^0.18.0
  uuid: ^3.0.0
```

### Step 2: Setup Firebase Cloud Function
Create a Cloud Function to send emails:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
});

exports.sendReceiptEmail = functions.https.onCall(async (data, context) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: data.recipientEmail,
      subject: `Receipt #${data.receiptNumber} from ${data.businessName}`,
      html: `
        <h2>Receipt #${data.receiptNumber}</h2>
        <p>Dear ${data.customerName},</p>
        <p>Thank you for your purchase of <strong>₦${data.totalAmount}</strong></p>
        <p><a href="${data.pdfUrl}">Download Receipt PDF</a></p>
        <p>Thank you for your business!</p>
      `,
      attachments: [{
        filename: `receipt_${data.receiptNumber}.pdf`,
        path: data.pdfUrl,
      }],
    };

    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error(error);
    return { success: false, error: error.message };
  }
});
```

### Step 3: Integrate into Checkout Screen

```dart
// In your checkout screen
import 'package:your_app/services/checkout_receipt_handler.dart';

// After successful payment:
await CheckoutReceiptHandler.handleCheckoutReceipt(
  context: context,
  businessName: businessProvider.businessName,
  customerName: customerName,
  customerEmail: customerEmail,
  items: cart.items,
  subtotal: cart.subtotal,
  tax: cart.tax,
  total: cart.total,
  paymentMethod: paymentMethod,
  customHeader: businessProvider.receiptHeader,
  customFooter: businessProvider.receiptFooter,
  paperWidth: settingsProvider.paperWidth,
  onComplete: (success) {
    if (success) {
      // Clear cart and show success
      cart.clearCart();
      Navigator.pop(context);
    }
  },
);
```

## Features

### Receipt Customization
- Support for 58mm thermal and 80mm standard paper sizes
- Custom header and footer text
- Business branding
- Item-wise breakdown
- Tax and discount calculations

### Email Notifications
- Automatic email to customer
- PDF attachment
- Professional email template
- Admin notification system

### Sharing Options
- Native share dialog
- WhatsApp integration
- Email client integration
- File management

### Admin Notifications
- Payment notifications in admin dashboard
- Receipt number tracking
- Customer information logging
- Timestamp tracking

## Error Handling

All services include comprehensive error handling:
- Firebase function errors
- Storage upload failures
- Email delivery issues
- File system errors

Errors are logged and user-friendly messages are displayed via SnackBar.

## Firestore Rules (for PDF storage)

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /receipts/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
      allow delete: if request.auth.uid == resource.metadata.createdBy;
    }
  }
}
```

## Testing

### Local Testing
1. Generate receipts without email (test PDF generation)
2. Mock email service responses
3. Test file sharing on different platforms

### Production Testing
1. Send test receipts to test email
2. Verify PDF generation quality
3. Test with various device screen sizes
4. Validate email delivery

## Security Considerations

1. **Email Validation**: Validate email format before sending
2. **File Storage**: Use secure Firebase Storage rules
3. **PDF Size**: Ensure PDFs don't exceed size limits
4. **Rate Limiting**: Implement rate limits on email sending
5. **User Privacy**: Don't store sensitive data in logs

## Troubleshooting

### PDF Generation Issues
- Ensure all fonts are available
- Check file path permissions
- Verify PDF dimensions for paper size

### Email Not Sending
- Verify Cloud Function is deployed
- Check Firebase credentials
- Validate email format
- Check Firebase logs for errors

### File Sharing Issues
- Ensure share_plus plugin is properly initialized
- Check file path is accessible
- Verify MIME types

## Future Enhancements

1. **Email Templates**: Custom branded email templates
2. **SMS Receipts**: Send receipt via SMS
3. **Bulk Sending**: Send receipts to multiple customers
4. **Receipt History**: Store and retrieve past receipts
5. **Digital Signature**: Add digital signatures to receipts
6. **Multi-currency**: Support multiple currencies
7. **Barcode**: Add QR/barcode for digital validation

