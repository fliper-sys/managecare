# Real Estate Business Module - Complete Implementation Guide

## Overview
The Real Estate module provides comprehensive property management, tenant tracking, lease management, and rent collection for real estate businesses. It includes secure property listings, tenant management, automated rent reminders, and integrated payment processing via Flutterwave.

## Features

### 1. Property Management
- **Add/Edit Properties**: Full CRUD operations with form validation
- **Image Upload**: Up to 8 images per property with automatic compression
- **Price Formatting**: Automatic currency (₦) formatting and validation
- **Property Details**: Bedrooms, bathrooms, parking, area (m²), type (residential/commercial/land)
- **Status Tracking**: Available, rented, or sold status

### 2. Tenant Management
- **Tenant Profiles**: Name, email, phone, property assignment
- **Email Validation**: RFC 5322 compliant email validation
- **Phone Validation**: International phone number support
- **Active/Inactive Status**: Track tenant status

### 3. Lease Management
- **Lease Creation**: Date range, monthly rent, security deposit
- **Document Attachment**: Store lease agreements (PDF/DOC)
- **Status Management**: Active, expired, terminated statuses
- **Date Validation**: Ensures end date is after start date

### 4. Rent Collection
- **Payment Tracking**: Pending, paid, overdue statuses
- **Flutterwave Integration**: Secure online payment processing
- **Manual Entry**: Support for manual payment recording
- **Owner Notifications**: Email notifications for payments received
- **Payment Reminders**: Automated reminders 1 day before due date

### 5. Financial Dashboard
- **Total Property Value**: Sum of all property prices
- **Monthly Rent Summary**: Total from active leases
- **Pending Rent**: Amounts not yet collected
- **Overdue Payments**: Track late payments
- **Collection Reports**: Rent collected within date ranges

## File Structure

```
lib/presentation/industry_specific/realestate/
├── screens/
│   ├── add_property_screen.dart          # Create new property
│   ├── edit_property_screen.dart         # Edit existing property
│   ├── property_listings_screen.dart     # View all properties
│   ├── property_details_screen.dart      # Property details
│   ├── tenant_management_screen.dart     # Tenant list & management
│   ├── lease_management_screen.dart      # Lease management
│   ├── rent_collection_screen.dart       # Rent collection interface
│   └── real_estate_dashboard_screen.dart # Main dashboard
├── widgets/
│   ├── property_form.dart                # Reusable property form
│   ├── tenant_form.dart                  # Tenant form with validation
│   ├── lease_form.dart                   # Lease creation/edit form
│   ├── property_card.dart                # Property display card
│   ├── tenant_card.dart                  # Tenant display card
│   └── payment_tracker.dart              # Payment status display
├── dialogs/
│   └── rent_collection_dialog.dart       # Rent payment dialog
├── providers/
│   └── real_estate_provider.dart         # State management & Firestore
└── models/ (in providers)
    ├── Property
    ├── Tenant
    ├── Lease
    ├── RentPayment
    ├── Booking
    ├── DocumentItem
    └── InventoryItem

data/repositories/industry_specific/
└── real_estate_repository.dart           # Abstract repository interface
```

## Setup Instructions

### 1. Add to main.dart

```dart
import 'package:business_manager/presentation/industry_specific/realestate/providers/real_estate_provider.dart';

// In MultiProvider:
ChangeNotifierProvider<RealEstateProvider>(
  create: (context) => RealEstateProvider(
    businessId: userBusinessId,
  ),
)
```

### 2. Add Routes (routes/app_router.dart)

```dart
GoRoute(
  path: '/realestate',
  builder: (context, state) => const RealEstateDashboardScreen(),
  routes: [
    GoRoute(
      path: 'properties/add',
      builder: (context, state) => const AddPropertyScreen(),
    ),
    GoRoute(
      path: 'properties/edit/:id',
      builder: (context, state) => EditPropertyScreen(
        propertyId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: 'properties',
      builder: (context, state) => const PropertyListingsScreen(),
    ),
    GoRoute(
      path: 'tenants',
      builder: (context, state) => const TenantManagementScreen(),
    ),
    GoRoute(
      path: 'leases',
      builder: (context, state) => const LeaseManagementScreen(),
    ),
    GoRoute(
      path: 'rent-collection',
      builder: (context, state) => const RentCollectionScreen(),
    ),
  ],
)
```

### 3. Configure Flutterwave

Update `rent_collection_dialog.dart`:
```dart
// Replace with your actual Flutterwave keys
final encryptionKey = 'YOUR_FLUTTERWAVE_ENCRYPTION_KEY';
final publicKey = 'YOUR_FLUTTERWAVE_PUBLIC_KEY';
```

Get keys from: https://dashboard.flutterwave.com/settings/apis

### 4. Firestore Security Rules

Rules are automatically included in `firestore.rules`:

```
// Real Estate Collections
- properties/{propertyId}
- tenants/{tenantId}
- leases/{leaseId}
- rent_payments/{paymentId}
- bookings/{bookingId}
- documents/{documentId}
- inventory/{inventoryId}
- notificationLogs/{logId}
```

### 5. Firestore Indexes

Create composite indexes in Firebase Console:
```
Collection: properties
Fields: status (Ascending), createdAt (Descending)

Collection: tenants
Fields: status (Ascending), createdAt (Descending)

Collection: leases
Fields: status (Ascending), startDate (Descending)

Collection: rent_payments
Fields: status (Ascending), dueDate (Ascending)
```

## API Reference

### RealEstateProvider Methods

#### Property Management
```dart
Future<void> loadProperties()           // Load all properties
Future<void> addProperty(Property)      // Create new property
Future<void> updateProperty(Property)   // Update existing property
Future<void> deleteProperty(String id)  // Delete property
List<Property> getAvailableProperties() // Get available properties
double getTotalPropertyValue()          // Sum of all property prices
```

#### Tenant Management
```dart
Future<void> loadTenants()              // Load all tenants
Future<void> addTenant(Tenant)          // Create new tenant
Future<void> updateTenant(Tenant)       // Update tenant
Future<void> deleteTenant(String id)    // Delete tenant
int getActiveTenants()                  // Count active tenants
```

#### Lease Management
```dart
Future<void> loadLeases()               // Load all leases
Future<void> addLease(Lease)            // Create new lease
double getTotalMonthlyRent()            // Sum of active lease rent
```

#### Rent Payment
```dart
Future<void> loadRentPayments()         // Load all payments
Future<void> recordRentPayment(RentPayment)
Future<void> updateRentPaymentStatus(String id, String status, {DateTime? paidDate})
List<RentPayment> getOverduePayments()  // Get overdue payments
double getPendingRent()                 // Sum of pending amounts
double getCollectedRent(DateTime start, DateTime end)
```

#### File Uploads
```dart
Future<List<String>> uploadPropertyImages(List<File>, {onProgress})
Future<String?> uploadPropertyDocument(File)
```

## Validation Rules

### Property Form
- **Title**: Required, non-empty
- **Location**: Required, non-empty
- **Price**: Required, > 0, numeric
- **Area**: Numeric, >= 0
- **Bedrooms/Bathrooms/Parking**: Numeric, >= 0
- **Images**: At least 1, max 8, each ≤ 2MB
- **Type**: residential | commercial | land

### Tenant Form
- **Name**: Required, non-empty
- **Email**: Required, valid RFC 5322 format
- **Phone**: Required, valid international format
- **Property ID**: Optional

### Lease Form
- **Property**: Required, selected from list
- **Tenant**: Required, selected from list
- **Start Date**: Required, valid date format (YYYY-MM-DD)
- **End Date**: Required, must be after start date
- **Monthly Rent**: Required, > 0
- **Deposit**: Required, >= 0
- **Status**: active | expired | terminated

## Testing

### Run Unit Tests
```bash
flutter test test/providers/real_estate_provider_test.dart
```

### Run Widget Tests
```bash
flutter test test/widgets/property_form_test.dart
```

### Run All Tests
```bash
flutter test
```

## Notification System

### Owner Email Notifications
Triggered for:
- Property created/updated
- New tenant assigned
- Lease created/updated
- Rent payment received
- Overdue payment reminder

### In-App Notifications
- Rent due reminders (1 day before)
- Payment received confirmations
- System alerts

## Image Optimization

- **Compression**: Automatic with flutter_image_compress
- **Max Size**: 2MB per image
- **Quality**: 75% JPEG
- **Min Width**: 800px
- **Max Images**: 8 per property

## Error Handling

### Network Errors
- Offline support with local caching
- Auto-retry on connection restore
- User-friendly error messages

### Validation Errors
- Field-level validation with error hints
- Form-level validation messages
- Real-time validation feedback

### Payment Errors
- Transaction ID logging
- Payment status tracking
- Retry mechanisms

## Production Checklist

- [ ] Firestore security rules deployed
- [ ] Firestore indexes created
- [ ] Flutterwave keys configured
- [ ] Email templates verified
- [ ] Notification service tested
- [ ] Image upload endpoint verified
- [ ] All unit tests passing
- [ ] All widget tests passing
- [ ] Performance optimized
- [ ] Error logging configured
- [ ] Backup and recovery plan

## Troubleshooting

### Images not uploading
- Check upload endpoint URL
- Verify API key is correct
- Ensure images are ≤ 2MB
- Check network connectivity

### Notifications not sending
- Verify email service is configured
- Check Firestore notificationLogs collection
- Verify owner email is set in business document

### Rent reminders not triggering
- Verify NotificationService is initialized
- Check system notifications are enabled
- Verify payment status is 'pending'

### Flutterwave payment fails
- Verify API keys are correct
- Check currency is NGN
- Ensure test mode matches environment
- Verify customer email is valid

## Support

For issues or questions:
1. Check Firestore console for data integrity
2. Review notification logs in Firestore
3. Check device console logs for errors
4. Verify all dependencies are up to date

## License

Part of the Manage Care business management platform.
