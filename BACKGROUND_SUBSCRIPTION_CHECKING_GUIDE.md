# Background Subscription Checking & Feature Access Control

## Overview

This document describes the complete background subscription checking system that validates subscription status and enforces feature access restrictions at runtime.

## Components

### 1. BackgroundSubscriptionChecker (`background_subscription_checker.dart`)

Monitors subscription status in the background and detects:
- **Subscription expiration** - Validates end dates
- **Status changes** - Active → Inactive transitions
- **Expiration warnings** - Alerts 7 days before expiry
- **Tier mismatches** - Between local cache and Firestore

**Key Methods:**
```dart
// Start periodic checking
startBackgroundChecking(String userId)

// Validate specific feature access
Future<(bool, String?)> validateFeatureAccess(BusinessModel business, String feature)

// Get subscription status
SubscriptionStatus getSubscriptionStatus(BusinessModel business)

// Get all statuses for user
Future<List<SubscriptionStatus>> getAllSubscriptionStatuses(String userId)
```

**Callbacks:**
```dart
onSubscriptionStatusChanged(String businessId, bool isValid)
onFeatureAccessDenied(String businessId, String message)
onSubscriptionExpiringSoon(String businessId, int daysLeft)
```

**Check Interval:** 30 minutes (configurable)

### 2. SubscriptionFeatureGuard (`subscription_feature_guard.dart`)

Enforces feature access restrictions at runtime with detailed logging.

**Key Methods:**
```dart
// Check if feature available
Future<bool> canAccessFeature({
  required BusinessModel business,
  required String feature,
  required String context,
})

// Assert access or throw exception
Future<void> assertFeatureAccess({
  required BusinessModel business,
  required String feature,
  required String context,
})

// Check if upgrade needed
bool needsUpgrade({
  required BusinessModel business,
  required String feature,
})

// Get upgrade information
UpgradePath getUpgradePath({
  required BusinessModel business,
  required String feature,
})

// Get feature availability matrix
Map<String, Map<String, bool>> getFeatureMatrix()

// Get feature requirement tier
String? getFeatureTierRequirement(String feature)
```

**Access Logging:**
```dart
// Get recent access attempts
List<FeatureAccessLog> getAccessLogs({
  String? businessId,
  String? feature,
  int limit = 100,
})

// Export for analysis
List<Map<String, dynamic>> exportAccessLogs()

// Clear logs
void clearAccessLogs()
```

### 3. EnhancedSubscriptionProvider (`enhanced_subscription_provider.dart`)

High-level provider combining both services for UI integration.

**Key Methods:**
```dart
// Initialize for user (starts background checking)
void initializeForUser(String userId)

// Check feature access
Future<bool> canAccessFeature({
  required BusinessModel business,
  required String feature,
  required String context,
})

// Get subscription details
SubscriptionDetails? getSubscriptionDetails(String businessId)

// Get all statuses
Future<List<SubscriptionStatus>> getAllSubscriptionStatuses(String userId)

// Compare subscription tiers
Map<String, dynamic> getSubscriptionComparison()

// Refresh subscription status
Future<void> refreshSubscriptionStatus(String userId)
```

## Feature Matrix

### Free Tier
- Basic sales tracking
- Product management (50 limit)
- Basic reports
- Single user

### Basic/Starter Tier
- All Free features
- Unlimited workers
- Advanced analytics
- Email receipts
- SMS notifications
- Up to 5 users

### Pro/Professional Tier
- All Basic features
- Multi-location support
- API access
- Payment processing
- Custom reports
- Priority support
- Up to 20 users

### Tier 3
- All Pro features
- White-label options
- SSO login
- Dedicated support
- Custom development
- Unlimited users

## Implementation

### 1. In AuthProvider (on login)

```dart
import 'package:provider/provider.dart';

void _initializeSubscriptionChecking(String userId) {
  // After successful login
  final subscriptionProvider = 
      Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
  
  // Start background checking
  subscriptionProvider.initializeForUser(userId);
  
  print('[AuthProvider] Subscription checking initialized for user: $userId');
}
```

### 2. In BusinessProvider (on business access)

```dart
Future<bool> canAccessFeature(String feature) async {
  if (_currentBusiness == null) return false;
  
  final subscriptionProvider = 
      Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
  
  return await subscriptionProvider.canAccessFeature(
    business: _currentBusiness!,
    feature: feature,
    context: 'business_provider_check',
  );
}
```

### 3. In Feature Screens

```dart
@override
void initState() {
  super.initState();
  _checkFeatureAccess();
}

Future<void> _checkFeatureAccess() async {
  final subscriptionProvider = 
      Provider.of<EnhancedSubscriptionProvider>(context, listen: false);
  
  try {
    await subscriptionProvider.assertFeatureAccess(
      business: businessProvider.currentBusiness!,
      feature: 'email_receipts',
      context: 'email_receipt_screen_init',
    );
    
    setState(() => _hasAccess = true);
  } on FeatureAccessDeniedException catch (e) {
    final upgradePath = subscriptionProvider.getUpgradePath(
      business: businessProvider.currentBusiness!,
      feature: 'email_receipts',
    );
    
    _showUpgradeDialog(upgradePath);
  }
}
```

### 4. Setup in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ... other providers
        ChangeNotifierProvider(
          create: (_) => EnhancedSubscriptionProvider(),
        ),
      ],
      child: MaterialApp(
        // ... app config
      ),
    );
  }
}
```

## Subscription Status Enum

```dart
enum SubscriptionAction {
  none,           // All good
  renewSoon,      // Expires in 3-7 days
  renewUrgent,    // Expires in 0-3 days
  renewImmediate, // Expired or inactive
}

SubscriptionStatus {
  String businessId
  String businessName
  String tier               // free, basic, pro, enterprise
  bool isActive            // In Firestore
  bool isValid             // Active + not expired
  DateTime? startDate
  DateTime? endDate
  int? daysUntilExpiration
  bool isExpiringWithinDays
  String statusMessage     // Human-readable
  bool needsAction
}
```

## Access Control Flow

```
User tries to access feature
    ↓
EnhancedSubscriptionProvider.canAccessFeature()
    ↓
Check subscription validity:
  - Is isSubscriptionActive true?
  - Is endDate in future? (or null)
  - Is subscription sync'd from Firebase?
    ↓ (if invalid)
    Return false + reason
    
  ↓ (if valid)
Check feature tier requirement:
  - Get required tier for feature
  - Compare with user's tier
    ↓ (if insufficient tier)
    Return false + upgrade reason
    
  ↓ (if sufficient tier)
  Return true
    ↓
Log access attempt + result
    ↓
Execute feature / Show upgrade dialog
```

## Timeout & Offline Handling

### Offline Mode (No Network)
1. Uses cached subscription status
2. Checks cache staleness (60-minute default)
3. If cache fresh: Allow feature access
4. If cache stale: Block feature, show sync message

### Timeout Handling (Firebase slow)
1. Background checker uses 5-second timeout
2. Falls back to local cache on timeout
3. Retries on next check cycle (30 minutes)

### Feature Access During Offline
1. Check passes if cache valid
2. Feature access allowed
3. User sees "(offline)" indicator
4. Features sync on reconnect

## Logging & Debugging

### Access Logs
Each feature access attempt is logged:
```dart
FeatureAccessLog {
  timestamp: DateTime
  businessId: String
  feature: String
  context: String      // Where accessed from
  granted: bool
  reason: String?      // Why denied (if applicable)
}
```

### Export Logs for Analysis
```dart
final logs = subscriptionProvider.exportAccessLogs();
// Returns List<Map<String, dynamic>> ready for JSON export
```

### Debug Feature Matrix
```dart
final matrix = subscriptionProvider.getFeatureMatrix();
// Returns:
// {
//   'free': { 'basic_sales': true, 'email_receipts': false, ... },
//   'basic': { 'basic_sales': true, 'email_receipts': true, ... },
//   ...
// }
```

## Error Handling

### FeatureAccessDeniedException

Thrown when feature access is denied:
```dart
try {
  await subscriptionProvider.assertFeatureAccess(...);
} on FeatureAccessDeniedException catch (e) {
  print('Feature: ${e.feature}');
  print('Tier: ${e.tier}');
  print('Message: ${e.message}');
  
  showDialog(
    context: context,
    builder: (_) => UpgradeDialog(
      featureName: e.feature,
      currentTier: e.tier,
      message: e.statusMessage,
    ),
  );
}
```

## Performance Considerations

1. **Background Checks**: 30-minute intervals (configurable)
2. **Cache Priority**: Uses local cache first (instant)
3. **Firebase Queries**: Only when cache stale
4. **Access Logs**: Capped at 1000 entries (auto-purge)
5. **Memory**: ~50KB per business subscription data

## Security Notes

1. **Server-Side**: Always validate on backend
2. **Client-Side**: This is UI enforcement only
3. **Expiration Check**: Compares with device DateTime
4. **Cache**: Encrypted by platform (iOS Keychain, Android Keystore)
5. **Logs**: Stored in memory only (not persisted)

## Migration from Old System

### Old Way (CurrentBusiness Provider)
```dart
bool canAccessFeature(String feature) {
  final tier = _currentBusiness!.subscriptionTier;
  // Only checks tier, doesn't check expiration
  return tier == 'pro' || tier == 'enterprise';
}
```

### New Way (Enhanced Subscription Provider)
```dart
Future<bool> canAccessFeature(String feature) async {
  return await subscriptionProvider.canAccessFeature(
    business: currentBusiness,
    feature: feature,
    context: 'screen_name',
  );
  // Checks: subscription valid + tier + expiration + access logs
}
```

## Testing

### Mock Subscription Status
```dart
final mockStatus = SubscriptionStatus(
  businessId: 'test-biz',
  businessName: 'Test Business',
  tier: 'pro',
  isActive: true,
  isValid: true,
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now().add(Duration(days: 30)),
  daysUntilExpiration: 30,
  isExpiringWithinDays: false,
);
```

### Test Feature Access
```dart
test('Pro tier can access email receipts', () async {
  final canAccess = await subscriptionProvider.canAccessFeature(
    business: mockProBusiness,
    feature: 'email_receipts',
    context: 'test',
  );
  expect(canAccess, true);
});
```

## Troubleshooting

### Features Still Accessible After Expiry
- Check: Is `subscriptionEndDate` set correctly?
- Check: Is `isSubscriptionActive` true?
- Fix: Manually refresh with `refreshSubscriptionStatus(userId)`

### Background Checking Not Working
- Check: Is `initializeForUser()` called on login?
- Check: Is `EnhancedSubscriptionProvider` in Provider list?
- Fix: Verify `LocalBusinessStorage` initialized

### Wrong Tier Showing
- Check: Last sync timestamp
- Check: Cache staleness (should be < 60 minutes)
- Fix: Force sync from Firestore

### Performance Issues
- Check: Too many businesses (>50) for one user?
- Fix: Increase check interval from 30 to 60 minutes
- Fix: Clear old access logs with `clearAccessLogs()`

## Future Enhancements

1. **Smart Checking**: Only check businesses that recently changed
2. **Push Notifications**: Firebase Cloud Messaging for expirations
3. **Tier Comparison**: Visual tier comparison UI
4. **Trial Periods**: Support for free trial features
5. **Grace Period**: Allow access 24h after expiration (with warning)
6. **Usage Analytics**: Track feature usage by tier

