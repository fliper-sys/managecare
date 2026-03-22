# Real Estate Integration - Quick Setup Guide

## Step 1: Register Real Estate Provider in main.dart

Find the `MultiProvider` or provider list in your `main.dart` and add:

```dart
ChangeNotifierProvider(
  create: (context) => RealEstateProvider(
    businessId: businessId,  // Get from auth provider
    userId: userId,          // Get from auth provider
  ),
),
```

**Location in main.dart**: After other business providers (barbershop, salon, wholesale)

## Step 2: Add Routes to app_router.dart

Add these route definitions to your `GoRouter` configuration:

```dart
// Real Estate Routes
GoRoute(
  path: AppRoutes.realEstateDashboard,
  builder: (context, state) => const RealEstateDashboardScreenEnhanced(),
),
GoRoute(
  path: AppRoutes.propertyListings,
  builder: (context, state) => const PropertyListingsScreen(),
),
GoRoute(
  path: AppRoutes.tenantManagement,
  builder: (context, state) => const TenantManagementScreenEnhanced(),
),
GoRoute(
  path: AppRoutes.leaseManagement,
  builder: (context, state) => const LeaseManagementScreenEnhanced(),
),
GoRoute(
  path: AppRoutes.rentCollection,
  builder: (context, state) => const RentCollectionScreenEnhanced(),
),
```

## Step 3: Update routes.dart

Add these route constants:

```dart
class AppRoutes {
  // ... existing routes ...
  
  // Real Estate Routes
  static const String realEstateDashboard = '/realestate/dashboard';
  static const String propertyListings = '/realestate/listings';
  static const String tenantManagement = '/realestate/tenants';
  static const String leaseManagement = '/realestate/leases';
  static const String rentCollection = '/realestate/rent-collection';
}
```

## Step 4: Add Navigation Items

Add to your navigation menu or dashboard:

```dart
// In navigation/menu
ListTile(
  leading: const Icon(Icons.home),
  title: const Text('Real Estate Dashboard'),
  onTap: () => context.go(AppRoutes.realEstateDashboard),
),
ListTile(
  leading: const Icon(Icons.apartment),
  title: const Text('Properties'),
  onTap: () => context.go(AppRoutes.propertyListings),
),
ListTile(
  leading: const Icon(Icons.people),
  title: const Text('Tenants'),
  onTap: () => context.go(AppRoutes.tenantManagement),
),
ListTile(
  leading: const Icon(Icons.description),
  title: const Text('Leases'),
  onTap: () => context.go(AppRoutes.leaseManagement),
),
ListTile(
  leading: const Icon(Icons.payments),
  title: const Text('Rent Collection'),
  onTap: () => context.go(AppRoutes.rentCollection),
),
```

## Step 5: Add Imports to Files Using Real Estate

Add these imports to any file that uses RealEstateProvider:

```dart
import 'package:provider/provider.dart';
import 'path_to/real_estate_provider.dart';
import 'path_to/property_listings_screen.dart';
import 'path_to/real_estate_dashboard_enhanced_screen.dart';
import 'path_to/tenant_management_enhanced_screen.dart';
import 'path_to/lease_management_enhanced_screen.dart';
import 'path_to/rent_collection_enhanced_screen.dart';
```

## Step 6: Verify Dependencies in pubspec.yaml

Ensure these dependencies are included:

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  cloud_firestore: ^4.0.0
  dio: ^5.0.0
  http_parser: ^4.0.0
  image_picker: ^1.0.0
  file_picker: ^5.0.0
```

Run `flutter pub get` to install if missing.

## Step 7: Test the Integration

1. Run `flutter pub get` to install dependencies
2. Run `flutter run` to start the app
3. Navigate to Real Estate Dashboard
4. Test each feature:
   - ✅ View properties
   - ✅ Add new property with images
   - ✅ Manage tenants
   - ✅ Create leases
   - ✅ Track rent payments

## Verification Checklist

- [ ] Provider registered in main.dart
- [ ] Routes added to app_router.dart
- [ ] Route constants in routes.dart
- [ ] Navigation menu updated
- [ ] All imports added
- [ ] pubspec.yaml dependencies installed
- [ ] No compilation errors (run `flutter analyze`)
- [ ] App runs without crashes
- [ ] Firebase configured for Firestore
- [ ] PHP endpoint accessible (test in browser first)

## Troubleshooting

### "RealEstateProvider not found"
- Verify provider is registered in main.dart MultiProvider
- Check import statement is correct
- Rebuild app: `flutter clean && flutter pub get && flutter run`

### "Route not found"
- Verify routes are added to GoRouter
- Check route paths match AppRoutes constants
- Ensure GoRoute is inside the GoRouter routes list

### "Image upload fails"
- Test PHP endpoint manually: POST to https://globalthrivealliance.com/emailtemplate/upload.php
- Verify API key is correct: 8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef
- Check network connectivity
- Verify file size limits (20MB for images, 10MB for documents)

### "Firestore errors"
- Verify Firebase is configured in your project
- Check Firestore security rules allow read/write for authenticated users
- Ensure businessId is valid and matches Firestore document

## File Locations

```
lib/
├── main.dart                          (Add provider)
├── routes/
│   ├── app_router.dart               (Add routes)
│   └── routes.dart                   (Add constants)
└── presentation/industry_specific/realestate/
    ├── providers/
    │   └── real_estate_provider.dart  (NEW)
    └── screens/
        ├── property_listings_screen.dart                (NEW)
        ├── real_estate_dashboard_enhanced_screen.dart   (NEW)
        ├── tenant_management_enhanced_screen.dart       (NEW)
        ├── lease_management_enhanced_screen.dart        (NEW)
        └── rent_collection_enhanced_screen.dart         (NEW)
```

## Success Indicators

After integration, you should see:
- Real Estate screens appear in navigation
- Dashboard shows property count and financial metrics
- Can add properties with images from device
- Images upload successfully to PHP endpoint
- Firestore console shows data being stored
- All operations (CRUD) work smoothly
- No console errors or warnings

## Performance Notes

- First load may take 2-3 seconds while loading Firestore data
- Image uploads depend on network speed and file size
- Dashboard refreshes automatically when data changes
- List views are optimized for 100+ items

## Next Phase

Once integration is complete:
1. Add Firestore security rules
2. Implement backup and recovery
3. Add reporting and analytics
4. Create advanced search filters
5. Add bulk operations support
6. Implement audit logging

## Support

For issues or questions:
1. Check the REAL_ESTATE_IMPLEMENTATION_GUIDE.md
2. Verify all steps completed in order
3. Run `flutter doctor` to check environment
4. Check app logs in Android Studio or Xcode

