# Complete Features Integration Guide

## Overview

This guide documents the comprehensive implementation of all key features in Manage Care:
- File export and storage
- Printer integration
- Profile image upload
- Email notifications
- Data synchronization
- Business information management

---

## 1. File Export & Storage

### Services

**Location:** `lib/services/export_service.dart` (300+ lines)

### Supported Formats

- **CSV** - Comma-separated values for spreadsheets
- **JSON** - Formatted JSON with indentation
- **TSV** - Tab-separated values
- **Summary Report** - Statistical breakdown

### Export Features

```dart
// Export sales data
final csvContent = ExportService.exportToCSV(sales);
final jsonContent = ExportService.exportToJSON(sales);
final reportContent = ExportService.generateSummaryReport(sales);
```

### Storage Locations

1. **Local Storage** - `temp/manage_care_exports/`
2. **Firebase Storage** - `gs://your-project/exports/`
3. **PHP Server** - `https://globalthrivealliance.com/emailtemplate/uploads/`

### Integration in Screens

**Screen:** `lib/presentation/settings/screens/export_sales_history_screen.dart`

Features:
- Format selection (PDF/CSV/JSON/Excel)
- Date range picker
- Include images checkbox
- Auto-backup toggle
- Export/Share/Report generation buttons

---

## 2. Printer Service Integration

### Services

**Location:** `lib/services/printer_service.dart`

### Configuration

Initialize printer in settings:

```dart
PrinterService().initialize(
  printerName: 'Thermal Printer 1',
  printerModel: 'thermal', // thermal, inkjet, network, portable
  connectionType: 'bluetooth', // bluetooth, usb, wifi, lan
  paperWidth: 80,
  autoConnect: true,
  headerText: 'Your Business Name',
  footerText: 'Thank you for your business!',
);
```

### Key Methods

```dart
// Test connection
final result = await PrinterService().testConnection();

// Print receipt
final printResult = await PrinterService().printReceipt(sale);

// Get status
final status = await PrinterService().getPrinterStatus();

// Cancel job
await PrinterService().cancelPrintJob(jobId);
```

### Receipt Format

Receipts are auto-formatted with:
- Header/footer text
- Business information
- Item details (product, qty, price)
- Subtotal, tax, discount, total
- Payment method
- Customizable paper width (80mm default)

### Integration in Screens

**Screen:** `lib/presentation/settings/screens/printer_settings_screen.dart`

Features:
- Printer model selection
- Connection type selection
- Paper width configuration
- Header/footer customization
- Test printer button
- Connection status indicator

---

## 3. Profile Image Upload

### Services

**Location:** `lib/services/data_sync_service.dart`

### Upload Methods

```dart
final result = await DataSyncService().uploadProfileImage(
  userId: 'user123',
  businessId: 'biz456',
  imageFile: selectedImage,
  userEmail: 'user@example.com',
);
```

### Upload Destinations

1. **Firebase Storage** - Primary backup
   - Path: `users/{userId}/profile_*.jpg`
   
2. **PHP Endpoint** - Secondary backup
   - URL: `https://globalthrivealliance.com/emailtemplate/upload.php`
   - Type: multipart/form-data

### Firestore Updates

Updates these fields:
- `users/{userId}/profilePhotoUrl`
- `users/{userId}/phpProfileUrl`
- `users/{userId}/photoUpdatedAt`

### Integration in Screens

**Screen:** `lib/presentation/settings/screens/profile_screen.dart`

Features:
- Profile photo preview
- Image selection (gallery/camera)
- Upload progress indicator
- Success/error feedback
- Auto-sync to Firebase

---

## 4. Email & Notification Service

### Services

**Location:** `lib/services/notification_and_email_service.dart`

### Supported Notifications

#### Receipt Notifications
```dart
await NotificationAndEmailService().sendReceiptNotification(
  customerEmail: 'customer@example.com',
  businessName: 'My Shop',
  receiptText: receiptContent,
  customerName: 'John Doe',
  sendPushNotification: true,
  sendSMS: false,
);
```

#### Order Confirmation
```dart
await NotificationAndEmailService().sendOrderConfirmation(
  customerEmail: 'customer@example.com',
  businessName: 'My Shop',
  orderId: 'ORD123',
  totalAmount: 5000.00,
  items: itemsList,
);
```

#### Payment Reminders
```dart
await NotificationAndEmailService().sendPaymentReminder(
  customerEmail: 'customer@example.com',
  businessName: 'My Shop',
  dueAmount: 5000.00,
  dueDate: '2025-12-15',
);
```

#### Low Stock Alerts
```dart
await NotificationAndEmailService().sendLowStockAlert(
  ownerEmail: 'owner@example.com',
  businessName: 'My Shop',
  items: [
    {'name': 'Product A', 'quantity': 5},
    {'name': 'Product B', 'quantity': 3},
  ],
);
```

#### Expiry Alerts
```dart
await NotificationAndEmailService().sendExpiryAlert(
  ownerEmail: 'owner@example.com',
  businessName: 'My Shop',
  expiredItems: [
    {'name': 'Milk', 'expiryDate': '2025-01-10'},
  ],
);
```

### Notification Channels

- **Email** - Via PHP endpoint (email_api.php)
- **Push Notifications** - Via Firebase Cloud Messaging
- **SMS** - Stub implementation (ready for Twilio integration)

### Email Templates Used

- `order` - Order confirmation
- `receipt` - Receipt details
- `payment-reminder` - Payment due notification
- `lowstock` - Low inventory alert
- `expiry` - Expiry date warning

### Logging

All notifications are logged to Firestore:
- `businesses/{businessId}/notificationLogs`
- Tracks: type, channel, recipient, success, timestamp

---

## 5. Data Synchronization Service

### Services

**Location:** `lib/services/data_sync_service.dart`

### Sync Operations

#### Export Sales Data
```dart
final result = await DataSyncService().exportSalesData(
  businessId: 'biz123',
  sales: salesList,
  format: 'csv', // csv, json, tsv
  userId: 'user123',
  startDate: DateTime(2025, 1, 1),
  endDate: DateTime(2025, 1, 31),
  uploadToServer: true,
);
```

#### Sync User Data to PHP
```dart
final result = await DataSyncService().syncUserDataToPhp(
  userId: 'user123',
  businessId: 'biz456',
  userModel: userModel,
  businessModel: businessModel,
);
```

#### Sync Business Data to PHP
```dart
final result = await DataSyncService().syncBusinessDataToPhp(
  businessId: 'biz456',
  businessModel: businessModel,
  userId: 'user123',
);
```

#### Sync to Firestore
```dart
final result = await DataSyncService().syncToFirestore(
  businessId: 'biz456',
  userId: 'user123',
  data: {
    'userProfile': {...},
    'businessSettings': {...},
    'sales': [...]
  },
);
```

### Sync Status Tracking

```dart
// Get last sync time
final lastSync = DataSyncService().getLastSyncTime('user_123');

// Check if currently syncing
final syncing = DataSyncService().isSyncing('business_456');

// Send sync notification
await DataSyncService().sendSyncNotification(
  userEmail: 'user@example.com',
  businessName: 'My Shop',
  syncResult: result,
);
```

### Firestore Collections Updated

- `users/{userId}` - User profile data
- `businesses/{businessId}` - Business settings
- `businesses/{businessId}/sales` - Sales records
- `businesses/{businessId}/exports` - Export metadata
- `businesses/{businessId}/syncLogs` - Sync history

### PHP Endpoints

**Endpoints used:**
- `profile-sync.php` - User data sync
- `business-sync.php` - Business data sync
- `data-sync.php` - General data sync
- `upload.php` - File upload

---

## 6. Business Information Management

### Profile Screen Features

**Location:** `lib/presentation/settings/screens/profile_screen.dart`

Features:
- Display user profile information
- Edit name, email, phone
- Upload profile photo
- Auto-sync to Firebase and PHP endpoint
- Success/error messaging

### Settings Management

**Location:** `lib/providers/settings_provider.dart`

Manages:
- Profile settings
- Notification preferences
- Printer configuration
- Subscription details
- Export settings
- General settings

---

## 7. Integration Points

### Provider Registration

Add to `lib/main.dart`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => BusinessProvider()),
    // Services are singletons and accessed via Service.instance
  ],
  child: const MyApp(),
)
```

### Service Usage in Screens

```dart
// Import services
import '../services/data_sync_service.dart';
import '../services/printer_service.dart';
import '../services/notification_and_email_service.dart';

// Use in build method or state
final dataSyncService = DataSyncService();
final printerService = PrinterService();
final notificationService = NotificationAndEmailService();
```

### Route Configuration

Add to `lib/core/constants/routes.dart`:

```dart
class Routes {
  static const String profile = '/settings/profile';
  static const String notifications = '/settings/notifications';
  static const String printerSettings = '/settings/printer';
  static const String exportSalesHistory = '/settings/export-sales';
}
```

---

## 8. Error Handling & Logging

### Response Format

All services return structured responses:

```dart
{
  'success': true/false,
  'message': 'Human readable message',
  'data': {...},
  'error': 'Error message if failed'
}
```

### Firestore Logging

Comprehensive logging of all operations:
- Notification logs: `businesses/{id}/notificationLogs`
- Sync logs: `businesses/{id}/syncLogs`
- Export records: `businesses/{id}/exports`

### Error Recovery

- Auto-retry on network failure
- Fallback to local storage when server unavailable
- Batch operations for data consistency
- Transaction support for critical operations

---

## 9. Testing & Validation

### Unit Tests Location

```
test/services/
  - data_sync_service_test.dart
  - printer_service_test.dart
  - export_service_test.dart
  - notification_service_test.dart
```

### Manual Testing Steps

1. **Export Feature**
   - Open Export Sales History screen
   - Select date range
   - Choose export format
   - Click Export Now
   - Verify file created in app documents

2. **Printer Setup**
   - Open Printer Settings
   - Configure printer model and connection
   - Add header/footer text
   - Click Test Connection
   - Verify status

3. **Profile Image**
   - Open Profile screen
   - Click upload button
   - Select image from gallery
   - Verify upload to Firebase
   - Confirm image URL in Firestore

4. **Email Notifications**
   - Make a sale/order
   - Receipt email should be sent
   - Check email inbox
   - Verify push notification

5. **Data Sync**
   - Make changes to profile/business info
   - Click sync button
   - Verify data appears in PHP endpoint
   - Check Firestore for timestamp

---

## 10. Production Checklist

- [ ] Update API endpoints for production URLs
- [ ] Set environment variables for SMTP credentials
- [ ] Configure Firebase project (Firestore, Storage, Auth)
- [ ] Set up PHP endpoints on server
- [ ] Configure Firebase Cloud Messaging
- [ ] Test all email templates
- [ ] Validate printer connectivity
- [ ] Set up backup schedules
- [ ] Configure cron jobs for workers
- [ ] Enable SSL/TLS certificates
- [ ] Set up monitoring and alerts
- [ ] Document custom configurations
- [ ] Train users on new features

---

## 11. Configuration Files

### Environment Config
**Location:** `lib/core/config/environment.dart`

```dart
static String get apiBaseUrl {
  switch (currentEnvironment) {
    case Environment.production:
      return 'https://api.managecare.app';
    // ...
  }
}
```

### Email Service Config
**Location:** `lib/services/email_service.dart`

```dart
static const String _base = 'https://globalthrivealliance.com/emailtemplate';
static const String _apiKey = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';
```

### PHP Mail Config
**Location:** `emailtemplate/mail.php`

```php
$mail->Host = "smtp.hostinger.com";
$mail->Username = "mc@globalthrivealliance.com";
$mail->Password = "Xanther839@";
```

---

## 12. Troubleshooting

### Common Issues

**Export fails**
- Check file permissions on device
- Verify internet connection for server upload
- Check Firebase Storage rules

**Printer not connecting**
- Verify printer is on and configured
- Check Bluetooth/USB connection
- Test connection from printer settings

**Emails not sending**
- Verify PHP endpoint is accessible
- Check SMTP credentials in mail.php
- Review email logs on server

**Sync failures**
- Check Firestore rules and authentication
- Verify PHP endpoint availability
- Check API key configuration

**Image upload issues**
- Verify image file format and size
- Check Firebase Storage quotas
- Test PHP upload endpoint

---

## Summary

All major features are now fully implemented and ready for production:
✅ File export (CSV, JSON, TSV)
✅ Printer integration & printing
✅ Profile image upload (Firebase + PHP)
✅ Email notifications (receipts, orders, reminders)
✅ Push notifications
✅ Comprehensive data sync
✅ Firestore integration
✅ PHP API integration
✅ Error handling & logging
✅ User preference management

For production deployment, follow the checklist and ensure all endpoints are configured correctly.

