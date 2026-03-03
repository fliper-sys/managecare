# Manage Care - Complete Feature Documentation

## Table of Contents
1. [Multi-Business Support](#multi-business-support)
2. [Authentication & Security](#authentication--security)
3. [Inventory Management](#inventory-management)
4. [Point of Sale (POS)](#point-of-sale-pos)
5. [Thermal Printing](#thermal-printing)
6. [Sales & Analytics](#sales--analytics)
7. [Admin Dashboard](#admin-dashboard)
8. [Subscription Management](#subscription-management)
9. [Settings & Configuration](#settings--configuration)
10. [Offline Support](#offline-support)
11. [Integration Services](#integration-services)
12. [Mobile Features](#mobile-features)

---

## Multi-Business Support

### Overview
Manage Care supports 9+ different business types, allowing a single app installation to manage multiple distinct businesses with business-specific features and data isolation.

### Supported Business Types
- **Pharmacy**: Prescription tracking, expiry dates, refill management
- **Retail**: General product sales, inventory tracking
- **Agriculture**: Livestock management, crop tracking, animal groups
- **Auto Repair**: Service tracking, parts inventory, repair orders
- **Salon**: Service booking, staff management, client profiles
- **Hotel**: Room management, booking system, guest services
- **Restaurant**: Menu management, table management, orders
- **Bar**: Drinks inventory, orders, stock management
- **Real Estate**: Property listings, client management, viewings

### Key Features
- **Business Selection Screen**: Users select their business type during onboarding
- **Business Context Isolation**: Each business operates independently with isolated data
- **Business Provider** (`lib/providers/business_provider.dart`):
  - Manages current business selection
  - Stores business configuration
  - Switches between businesses
- **Per-Business Settings**: Each business has its own settings, users, and configurations
- **Firestore Structure**:
  ```
  /businesses/{businessId}/
    ├── settings/
    ├── products/
    ├── inventory/
    ├── transactions/
    └── users/
  ```

### Usage
- Users select business type on first launch
- Business ID used throughout app for data filtering
- All queries filtered by `businessId` to maintain isolation

---

## Authentication & Security

### Overview
Complete user authentication system with Firebase integration, session management, and security features.

### Features
- **Email/Password Authentication**: Sign up and login with email
- **Session Management**: Track authenticated user sessions
- **Token Refresh**: Automatic token refresh before expiration
- **User Roles**: Different permission levels (admin, manager, staff)
- **Password Security**: Hashed storage, reset via email
- **Auto-Logout**: Session timeout after inactivity

### Key Files
- `lib/providers/auth_provider.dart`: Authentication state management
- `lib/services/auth_service.dart`: Firebase auth integration
- `lib/presentation/auth/`: Login/register screens

### Authentication Flow
1. User enters email and password
2. Firebase authenticates credentials
3. Auth token generated and stored
4. User profile loaded from Firestore
5. Business selection loaded
6. App navigates to dashboard

### Security Features
- Passwords never stored locally (Firebase-managed)
- Auth tokens stored securely in device keychain
- Auto-logout after 30 minutes inactivity
- Token refresh before expiration
- Email verification for new accounts

### Usage Example
```dart
final authProvider = context.read<AuthProvider>();
await authProvider.login(email, password);

if (authProvider.isAuthenticated) {
  // Navigate to dashboard
}
```

---

## Inventory Management

### Overview
Comprehensive inventory tracking system supporting multiple business types with real-time stock monitoring and low-stock alerts.

### Core Features

#### Product Management
- Create, read, update, delete products
- Product categories and subcategories
- SKU/barcode tracking
- Pricing management
- Product descriptions and images
- Supplier information

#### Stock Tracking
- Real-time quantity tracking
- Multiple storage locations
- Stock movements (inbound, outbound)
- Stock reconciliation
- Bulk updates

#### Low-Stock Detection
- **Automatic Monitoring**: Detects products below threshold
- **Critical Items**: Alerts for critically low stock
- **Low-Stock Screen**: Visual dashboard of low items
- **Configurable Thresholds**: Set per-product or default thresholds
- **Email Alerts**: Notifications for low-stock items
- **Real-Time Updates**: Stream-based status changes

### Key Files
- `lib/services/low_stock_detection_service.dart`: Detection logic
- `lib/presentation/inventory/screens/low_stock_products_screen.dart`: UI display
- `lib/domain/entities/product_entity.dart`: Product data model
- `lib/data/models/product_model.dart`: Firestore mapping

### Storage Structure
Products stored in two collections:
- **`/businesses/{id}/products`**: Main product catalog
- **`/businesses/{id}/inventory`**: Inventory quantities

**Field Names**: `quantity` or `stock` (service handles both)

### Low-Stock Detection Logic
```dart
// Service merges both collections and reads quantity/stock
final lowStockProducts = await detectLowStockProducts(
  businessId: 'biz123',
  threshold: 10, // Alert when quantity <= 10
);

// Stream for real-time updates
lowStockService.streamLowStockProducts(businessId)
  .listen((products) {
    // Update UI with current low-stock items
  });
```

### Example Use Cases
- **Pharmacy**: Alert when medicine stock < 20 units
- **Retail**: Notify when popular items drop below reorder point
- **Restaurant**: Alert when ingredient stock critically low
- **Agriculture**: Monitor livestock feed inventory

---

## Point of Sale (POS)

### Overview
Complete transaction management system for recording sales, managing payments, and generating receipts.

### Features

#### Transaction Management
- Record sales transactions
- Support multiple payment methods (cash, card, mobile money)
- Customer tracking
- Discount and tax calculation
- Refund/return processing

#### Receipt Generation
- Full receipt with itemized details
- Business name and address
- Transaction ID and date/time
- Item quantities and prices
- Subtotal, tax, discount, total
- Payment method display
- Customer information (optional)

#### Payment Methods
- Cash payments
- Card payments (integrated with Flutterwave)
- Mobile money (where applicable)
- Cheques
- Credit/account

#### Receipt Customization
- Business name formatting
- Address display
- Header/footer text
- Tax percentage
- Receipt numbering format
- Logo inclusion (where supported)

### Key Files
- `lib/services/thermal_printing_service.dart`: Receipt generation
- `lib/services/esc_pos_receipt_generator.dart`: ESC/POS formatting
- `lib/presentation/sales/`: Sales screens
- `lib/domain/entities/receipt_entity.dart`: Receipt data model

### Receipt Data Structure
```dart
class Receipt {
  final String receiptNumber;
  final DateTime receiptDate;
  final List<ReceiptLineItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final String paymentMethod;
  final String? customerName;
}

class ReceiptLineItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double total;
}
```

### Usage Example
```dart
final result = await ThermalPrintingService().printFullReceipt(
  businessName: 'My Shop',
  receiptNumber: 'RCP-001',
  receiptDate: DateTime.now(),
  items: [...],
  subtotal: 100.0,
  tax: 10.0,
  discount: 0.0,
  total: 110.0,
  paymentMethod: 'Cash',
);
```

---

## Thermal Printing

### Overview
Complete Bluetooth thermal printer integration for printing receipts and reports on mobile thermal printers.

### Features

#### Printer Discovery
- Scan for paired Bluetooth thermal printers
- Display list of available devices
- Store selected printer preferences
- Support for multiple printers per business

#### Connection Management
- Connect to printer via MAC address
- Connection status monitoring (5-second checks)
- Automatic reconnection with exponential backoff
- Graceful disconnect with resource cleanup
- Connection persistence across app navigation

#### Printing Capabilities
- **Full Receipts**: Complete transaction details with formatting
- **Simple Text**: Plain text printing for testing
- **Raw Bytes**: Direct ESC/POS command printing
- **Test Prints**: Verify printer functionality

#### Paper Width Support
- **58mm**: Receipt printer (standard POS)
- **80mm**: Standard thermal printer

#### Technical Features
- Chunked transmission (512 bytes per chunk)
- Intelligent delays (50ms between chunks, 200ms final)
- Buffer overflow prevention
- Connection status streaming
- Verbose diagnostic logging with timestamps
- Web and Android platform support

### Key Files
- `lib/services/thermal_printer_manager.dart`: Core manager
- `lib/services/thermal_printing_service.dart`: High-level API
- `lib/services/esc_pos_receipt_generator.dart`: ESC/POS command generation
- `lib/presentation/settings/screens/printer_settings_screen.dart`: UI

### Printer Manager Architecture
```
ThermalPrinterManager (facade)
  ├── WebPrinterImpl (web platform)
  └── AndroidPrinterImpl (Android platform)
      ├── Connection monitoring (5s timer)
      ├── Auto-reconnection (3s delay, exponential backoff)
      └── Raw byte transmission (chunked, delayed)
```

### Printer Status Enum
```dart
enum PrinterStatus {
  connected,      // Ready to print
  disconnected,   // Not connected
  printing,       // Actively printing
  error,          // Error state
  unknown,        // Status unknown
}
```

### Connection Flow
1. **Discover**: Scan for paired Bluetooth devices
2. **Select**: User chooses printer from list
3. **Connect**: Establish BLE connection
4. **Monitor**: Start periodic connection checks
5. **Print**: Send ESC/POS bytes in chunks
6. **Verify**: Status stream confirms success

### Status Stream for Diagnostics
```dart
final manager = ThermalPrinterManager();

// Subscribe to status changes (for logging/debugging)
manager.onStatusChanged.listen((status) {
  print('Printer status: $status');
});

// Status changes emit with timestamps:
// [2026-01-29T14:32:15.123Z] Status changed -> connected
// [2026-01-29T14:32:20.456Z] connectionStatus check: true
// [2026-01-29T14:32:25.789Z] Sending 256 bytes...
```

### Usage Example
```dart
final service = ThermalPrintingService();
await service.initialize();

// Discover printers
final printers = await service.getAvailablePrinters();

// Connect
final connected = await service.connectToPrinter(printers.first);

// Print receipt
final success = await service.printFullReceipt(
  businessName: 'Shop Name',
  receiptNumber: 'RCP-001',
  // ... other details
);

// Test connection
final testResult = await service.testPrinterConnection();
```

### Disconnect Compatibility
The manager handles both `disconnect()` method and `disconnect` getter forms for compatibility:
```dart
// Tries both forms
await PrintBluetoothThermal.disconnect();  // method
await PrintBluetoothThermal.disconnect;    // getter
```

---

## Sales & Analytics

### Overview
Sales tracking and reporting system providing insights into business performance.

### Features

#### Sales Tracking
- Real-time transaction recording
- Daily sales summaries
- Sales by payment method
- Hourly breakdown
- Product-level sales tracking

#### Reports
- Daily sales reports
- Weekly/monthly summaries
- Payment method analysis
- Top-selling products
- Revenue trends

#### Dashboards
- Quick overview of today's sales
- Total transactions
- Total revenue
- Average transaction value
- Peak sales times

#### Analytics
- Sales trend analysis
- Payment method preferences
- Customer purchase patterns
- Seasonal trends (where applicable)

### Key Files
- `lib/presentation/sales/`: Sales screens
- `lib/services/sales_service.dart`: Sales logic
- `lib/providers/sales_provider.dart`: State management

### Data Structure
```dart
class SalesData {
  final DateTime date;
  final double totalRevenue;
  final int transactionCount;
  final Map<String, double> byPaymentMethod;
  final Map<String, int> topProducts;
}
```

### Usage Example
```dart
final salesProvider = context.read<SalesProvider>();

// Get today's sales
final todaySales = await salesProvider.getDailySales(DateTime.now());

// Get sales by payment method
final byMethod = todaySales.byPaymentMethod;
// { 'Cash': 450.0, 'Card': 320.0 }
```

---

## Admin Dashboard

### Overview
Administrative interface for business management, payment approvals, and user administration.

### Features

#### Dashboard Overview
- Key metrics snapshot
- Today's performance
- Recent transactions
- Low-stock alerts
- Pending approvals

#### Payment Approvals
- View pending payments
- Approve/reject transactions
- Set approval thresholds
- Audit trail of approvals
- Multi-level approval workflows

#### User Management
- View active users
- Assign roles (admin, manager, staff)
- Manage permissions
- User activity logs
- Deactivate/remove users

#### Business Settings
- Edit business information
- Configure features (printer, notifications)
- Set business hours
- Manage locations/branches
- Tax and discount settings

#### Reports
- Comprehensive sales reports
- Payment reconciliation
- User activity reports
- Inventory reports
- Financial summaries

### Key Files
- `lib/presentation/admin/`: Admin screens
- `lib/providers/admin_provider.dart`: Admin state

### Access Control
- Only users with admin role can access
- Business-level admin (manages own business)
- System admin (manages all businesses)

---

## Subscription Management

### Overview
Flexible subscription system supporting multiple business plans with auto-renewal and feature access control.

### Features

#### Plan Types
- **Free Plan**: Limited features, basic reporting
- **Starter**: Basic POS, 1 user, limited products
- **Professional**: Full POS, 5 users, unlimited products, advanced reports
- **Enterprise**: Everything + custom features, dedicated support

#### Subscription Features
- Monthly/annual billing cycles
- Auto-renewal with reminder notifications
- Payment via Flutterwave or local methods
- Plan upgrades/downgrades
- Proration calculation
- Subscription history tracking

#### Background Checking
- Periodic check of subscription status (every 24 hours)
- Automatic downgrade on expired subscription
- Feature access blocked for expired plans
- Renewal reminders (7 days, 1 day before expiration)

#### Payment Processing
- Secure payment gateway integration
- Multiple currency support
- Invoice generation
- Payment receipts
- Refund processing

### Key Files
- `lib/services/subscription_service.dart`: Subscription logic
- `lib/providers/subscription_provider.dart`: State management
- `lib/presentation/subscription/`: Subscription screens

### Subscription Data Structure
```dart
class Subscription {
  final String planId;
  final String planName;
  final DateTime startDate;
  final DateTime? endDate;
  final double amount;
  final String billingCycle; // 'monthly' or 'annual'
  final bool autoRenew;
  final String status; // 'active', 'expired', 'pending'
}
```

### Background Subscription Checking
```dart
// Runs periodically (background task)
void _checkSubscriptionStatus() {
  final subscription = await subscriptionService.getActiveSubscription();
  
  if (subscription.endDate.isBefore(DateTime.now())) {
    // Notify user, disable premium features
  }
}
```

---

## Settings & Configuration

### Overview
Comprehensive settings management for user preferences, printer configuration, and business settings.

### Features

#### Printer Settings
- Printer model selection
- Paper width (58mm/80mm)
- Connection type (Bluetooth/USB)
- Auto-connect on startup
- Header/footer text customization
- Enable/disable printing

#### Notification Settings
- Email notifications
- In-app notifications
- Notification types (low-stock, sales, payments)
- Notification frequency
- Quiet hours

#### Business Settings
- Business name
- Address
- Phone number
- Email
- Tax ID
- Currency
- Timezone

#### User Preferences
- Language selection
- Theme (light/dark mode)
- Date/time format
- Number format
- Default payment method

### Key Files
- `lib/providers/settings_provider.dart`: Settings state
- `lib/presentation/settings/`: Settings screens
- Firestore path: `/businesses/{id}/settings/{userId}`

### Settings Data Structure
```dart
class Settings {
  // Printer settings
  bool printerEnabled;
  String printerModel;
  String paperWidth;
  String connectionType;
  bool autoConnect;
  bool printHeader;
  String? headerText;
  
  // Notification settings
  List<String> notificationTypes;
  bool emailNotifications;
  
  // Business settings
  String businessName;
  String address;
  String phone;
  
  // User preferences
  String language;
  String theme;
}
```

### Updating Settings
```dart
final settings = context.read<SettingsProvider>();

await settings.updatePrinterSettings(
  businessId,
  userId,
  paperWidth: '80',
  autoConnect: true,
);
```

---

## Offline Support

### Overview
Complete offline-first capability allowing the app to function without internet connectivity and sync when reconnected.

### Features

#### Local Storage
- Hive database for local caching
- Product catalog cached locally
- Transactions stored temporarily
- User preferences stored locally
- Settings synced to cloud

#### Sync Service
- Detects network connectivity
- Automatic sync on reconnection
- Conflict resolution (last-write-wins)
- Batch syncing for efficiency
- Retry logic for failed syncs

#### Data Persistence
- All critical data persisted locally
- Transaction queue maintained offline
- Images cached for offline access
- Maps cached for offline use

#### Offline Limitations
- No real-time analytics (cached)
- No multi-user sync (temporary conflict)
- Limited to local printer (no cloud printing)

### Key Files
- `lib/services/sync_service.dart`: Sync logic
- `lib/services/local_storage_service.dart`: Local DB
- `lib/providers/connectivity_provider.dart`: Network state

### Offline Flow
1. User opens app (internet optional)
2. Local data loaded from Hive
3. Network check performed
4. If online, sync queued changes to Firestore
5. If offline, allow local operations
6. Transactions stored in queue
7. On reconnection, queue synced automatically

---

## Integration Services

### Overview
Third-party service integrations providing extended functionality.

### Firebase Integration
- **Authentication**: User login/signup
- **Firestore**: Real-time database
- **Storage**: Image and document storage
- **Cloud Functions**: Backend business logic
- **Messaging**: Push notifications

### Payment Integration (Flutterwave)
- Card payments
- Mobile money transfers
- Bank transfers
- Payment verification
- Webhook handling

### Email Service
- Transactional emails (receipts, confirmations)
- Promotional emails
- Subscription renewal reminders
- Low-stock alerts
- Report delivery

### Barcode Service
- Barcode scanning (via camera)
- Barcode generation
- QR code support
- Inventory tracking via barcode

### Key Files
- `lib/services/firebase_service.dart`
- `lib/services/payment_service.dart`
- `lib/services/email_service.dart`
- `lib/services/barcode_service.dart`

---

## Mobile Features

### Overview
Platform-specific features leveraging mobile device capabilities.

### Android Features
- Bluetooth thermal printer support
- Barcode camera scanning
- Background task scheduling
- Notification channels
- App widget support

### iOS Features
- Bluetooth thermal printer support
- Camera access for scanning
- Background processing
- Home screen widgets
- AirPrint support (future)

### Web Features
- System print dialog
- Local storage (IndexedDB)
- Service workers (offline support planned)
- Progressive web app (PWA) capabilities

### Permissions
- Camera (for barcode scanning)
- Bluetooth (for printer)
- Location (optional, for delivery tracking)
- Storage (for image uploads)
- Contacts (optional, for customer import)

### Background Tasks
- Subscription status checking
- Data syncing
- Notification delivery
- Report generation
- Cache maintenance

---

## Architecture Overview

### Layered Architecture
```
Presentation Layer
├── Screens
├── Widgets
├── Providers (State Management)
└── Routes

Domain Layer
├── Entities
├── Repositories (Interfaces)
└── Use Cases

Data Layer
├── Models
├── Data Sources (Local/Remote)
└── Repository Implementations

Services Layer
├── Firebase Service
├── Printing Service
├── Sync Service
├── Payment Service
└── Notification Service

Core Layer
├── Theme
├── Constants
├── Utils
└── Error Handling
```

### State Management
- **Provider**: Global state and business logic
- **ChangeNotifier**: Local UI state changes
- **StreamController**: Real-time status updates (printer, connectivity)

### Navigation
- Go Router: Type-safe routing
- Route guards: Authentication checks
- Deep linking support

### Data Storage
- **Firestore**: Cloud database
- **Hive**: Local cache
- **SharedPreferences**: Simple key-value storage
- **Device File System**: Images, documents

---

## Configuration

### Environment Setup
```bash
# Install dependencies
flutter pub get

# Code generation
flutter pub run build_runner build

# Run on device/emulator
flutter run

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release

# Build Web
flutter build web --release
```

### Firebase Configuration
- Create Firebase project
- Add Android/iOS/Web apps
- Download configuration files
- Enable Firestore, Auth, Storage
- Set security rules

### API Keys
- Flutterwave public/secret keys
- Email service credentials
- Barcode service (if external)

---

## Summary

Manage Care is a comprehensive business management application with:
- **9+ business types** supported simultaneously
- **Complete POS system** with thermal printing
- **Real-time inventory** monitoring with low-stock alerts
- **Sales analytics** and reporting
- **Subscription management** with flexible plans
- **Offline-first** architecture with automatic syncing
- **Multi-platform** support (Android, iOS, Web)
- **Secure authentication** and business isolation
- **Extensible integration** with third-party services

For detailed implementation guides on specific features, refer to the corresponding documentation files in the project.
