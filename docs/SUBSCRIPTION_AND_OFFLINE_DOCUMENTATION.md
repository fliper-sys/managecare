# Subscription System Documentation

## Overview
Manage Care implements a comprehensive subscription management system that handles:
- Subscription tier management (Free, Basic, Pro, Tier3)
- Feature access control based on subscription level
- Subscription validation and enforcement
- Offline access to subscription data
- Local caching of subscription information

## Subscription Tiers

### Free Tier
- **Features**: Limited to basic operations
- **Cost**: $0
- **Maximum Workers**: 1
- **Features**:
  - Basic sales tracking
  - Single location
  - Manual reporting
  - Email support

### Basic Tier
- **Features**: Standard business operations
- **Cost**: $9.99/month or $99.99/year
- **Maximum Workers**: 5
- **Additional Features**:
  - 5 staff members
  - Sales analytics
  - Inventory management
  - Customer management
  - Email & support

### Pro Tier
- **Features**: Advanced business operations
- **Cost**: $24.99/month or $249.99/year
- **Maximum Workers**: 20
- **Additional Features**:
  - 20 staff members
  - Advanced analytics
  - Multi-location support
  - Priority support
  - API access
  - Custom reports

### Tier 3
- **Features**: Full platform access
- **Cost**: Custom pricing
- **Maximum Workers**: Unlimited
- **Additional Features**:
  - Unlimited staff
  - Dedicated account manager
  - Custom development
  - SLA guarantee
  - White-label options

## Data Model

### SubscriptionPlan
```dart
{
  'businessId': String,              // Reference to business
  'tier': String,                    // 'free', 'basic', 'pro', 'enterprise'
  'startDate': DateTime,             // Subscription start date
  'endDate': DateTime,               // Subscription expiration date
  'status': String,                  // 'active', 'expired', 'canceled'
  'paymentMethod': String,           // 'flutterwave', 'manual', 'card'
  'durationInDays': int,            // Days duration (30, 365, etc.)
  'totalPrice': double,              // Total cost
  'autoRenew': bool,                 // Auto-renewal enabled
  'notes': String,                   // Admin notes
  'createdAt': DateTime,             // Creation timestamp
  'updatedAt': DateTime,             // Last update timestamp
}
```

### BusinessModel Fields
```dart
{
  'subscriptionTier': String,        // Current subscription tier
  'isSubscriptionActive': bool,      // Subscription is currently active
  'subscriptionStartDate': DateTime, // When subscription started
  'subscriptionEndDate': DateTime,   // When subscription expires
  'durationDays': int,              // Original subscription duration
  'totalPrice': double,              // Subscription cost
}
```

## Local Storage

### User Data Storage
File: `lib/services/local_user_storage.dart`

Stores:
- User ID
- Email
- Full name
- Phone number
- Photo URL
- Business ID
- Owner status
- Auto-login preference

**Key Methods**:
- `saveUser(UserModel)` - Save user after login
- `getCachedUser()` - Retrieve cached user
- `updateCachedUser()` - Update specific fields
- `isAutoLoginEnabled()` - Check auto-login status
- `clearUser()` - Clear on logout

### Business Data Storage
File: `lib/services/local_business_storage.dart`

Stores:
- All user's businesses
- Current selected business
- Individual business details
- Last sync timestamp
- Cache staleness info

**Key Methods**:
- `saveBusinessList(List<BusinessModel>)` - Cache all businesses
- `saveBusiness(BusinessModel)` - Cache single business
- `getCachedBusinesses()` - Get all cached businesses
- `getCachedBusiness(String)` - Get specific business by ID
- `setCurrentBusiness(String)` - Set current selection
- `getCurrentBusiness()` - Get current business
- `isCacheStale()` - Check if cache needs refresh
- `getCacheStats()` - Get cache statistics

## Auto-Login Flow

### Initialization Sequence
1. **App Start** → `AuthProvider._init()` called
2. **Local Storage Init** → `_initializeLocalStorage()` executes
3. **Check Auto-Login** → `isAutoLoginEnabled()` checked
4. **Load Cached User** → `getCachedUser()` restores user
5. **Set Status** → User marked as authenticated
6. **Validate Subscription** → Background check of subscription
7. **Sync with Firebase** → Update profile in background
8. **Enable Offline Access** → Cached data available immediately

### Code Flow
```dart
Future<void> _initializeLocalStorage() async {
  _localStorage = await LocalUserStorage.create();
  
  if (_localStorage!.isAutoLoginEnabled()) {
    final cachedUser = _localStorage!.getCachedUser();
    if (cachedUser != null) {
      // Restore cached user immediately (offline mode)
      _currentUser = cachedUser;
      _status = AuthStatus.authenticated;
      
      // Validate subscription in background
      _subscriptionValidated = await _subscriptionService
          .validateAndUpdateSubscriptionStatus(_currentUser!.id);
      
      // Sync with Firebase in background (non-blocking)
      _syncCachedUserWithFirebase(cachedUser.id);
      
      notifyListeners();
    }
  }
}
```

## Offline Features

### What Works Offline
- ✅ View cached user information
- ✅ View cached business data
- ✅ View cached sales/transaction history
- ✅ View local inventory
- ✅ Navigate app UI
- ✅ Access settings and reports

### What Requires Connection
- ❌ Login (first time)
- ❌ Create new business
- ❌ Sync transactions to cloud
- ❌ Update subscription
- ❌ Real-time notifications
- ❌ Cloud backups

### Offline Indicators
The app will show `[isUsingCachedData]` when:
- Businesses loaded from local storage
- User syncing with Firebase fails
- Network unavailable

## Subscription Validation

### Validation Points
1. **Auto-Login** - Validates subscription status
2. **App Startup** - Periodic validation
3. **Feature Access** - Checks feature access
4. **Business Load** - Verifies subscription tier
5. **Manual Validation** - User can force refresh

### Validation Logic
```dart
bool isSubscriptionValid(BusinessModel? b) {
  if (b == null) return false;
  
  // Check tier is valid (not free)
  final tier = b.subscriptionTier.toLowerCase();
  if (!(tier == 'basic' || tier == 'pro' || tier == 'enterprise')) 
    return false;
  
  // Check subscription is active
  if (!b.isSubscriptionActive) return false;
  
  // Check expiration date
  final end = b.subscriptionEndDate;
  if (end != null && DateTime.now().isAfter(end)) return false;
  
  return true;
}
```

## Feature Access Control

### Implementation
File: `lib/providers/business_provider.dart`

Method: `isFeatureAvailable(String feature)`

### Available Features
```dart
switch (feature) {
  case 'unlimited_workers':
    return tier == 'professional' || tier == 'enterprise';
  
  case 'advanced_analytics':
    return tier == 'professional' || tier == 'enterprise';
  
  case 'multi_location':
    return tier == 'professional' || tier == 'enterprise';
  
  case 'api_access':
    return tier == 'professional' || tier == 'enterprise';
  
  case 'sso_login':
    return tier == 'enterprise';
  
  case 'white_label':
    return tier == 'enterprise';
  
  default:
    return false;
}
```

### Usage Example
```dart
if (businessProvider.isFeatureAvailable('advanced_analytics')) {
  // Show advanced reports
} else {
  // Show upgrade prompt
}
```

## Cache Management

### Cache Statistics
Get cache info for debugging:
```dart
final stats = businessProvider.getCacheStats();
// Returns:
// {
//   'totalCachedBusinesses': 2,
//   'currentBusinessId': 'business_123',
//   'lastSyncTime': '2025-12-08T10:30:00.000Z',
//   'isCacheStale': false,
//   'businessesInCache': [...]
// }
```

### Cache Staleness
- **Default**: 60 minutes
- **Check**: `isCacheStale(maxAgeMinutes: 60)`
- **Refresh**: Auto-refresh on app restart

## Integration Points

### AuthProvider
- `_initializeLocalStorage()` - Initialize on app start
- `login()` - Save user after successful login
- `logout()` - Clear all cached data
- `_syncCachedUserWithFirebase()` - Background sync

### BusinessProvider
- `loadUserBusinesses()` - Load and cache businesses
- `setCurrentBusinessAndSave()` - Save selection
- `getCachedCurrentBusiness()` - Get offline business
- `getCachedBusinesses()` - Get all offline businesses
- `clearCachedBusinessData()` - Clear on logout

### SubscriptionService
- `validateAndUpdateSubscriptionStatus()` - Validate tier
- `getSubscriptionTier()` - Get current tier
- `getRemainingDays()` - Days until expiration

## Error Handling

### Network Errors
```dart
try {
  _userBusinesses = await _repository.getUserBusinesses(userId);
} catch (e) {
  // Fallback to cached data
  _userBusinesses = _localStorage!.getCachedBusinesses();
  _isUsingCachedData = true;
}
```

### Cache Errors
```dart
BusinessModel? getCachedCurrentBusiness() {
  try {
    return _localStorage!.getCurrentBusiness();
  } catch (e) {
    print('[Error] $e');
    return _currentBusiness; // Return in-memory copy
  }
}
```

## Logging

### Key Log Tags
- `[AuthProvider]` - Authentication events
- `[LocalUserStorage]` - User storage operations
- `[BusinessProvider]` - Business operations
- `[LocalBusinessStorage]` - Business storage operations
- `[SubscriptionService]` - Subscription validation

### Debug Example
```
I/flutter: [AuthProvider] Auto-login: restoring cached user user@example.com
I/flutter: [BusinessProvider] Loading businesses for user: user_123
I/flutter: [LocalBusinessStorage] Saved 2 businesses to local storage
I/flutter: [AuthProvider] Syncing cached user with Firebase...
I/flutter: [AuthProvider] Successfully synced user with Firebase
```

## Best Practices

### For Users
1. **Enable Auto-Login** - Check "Remember me" on login
2. **Keep App Updated** - Ensure latest subscription data
3. **Check Expiration** - Renew before subscription expires
4. **Monitor Usage** - Track worker count and features

### For Developers
1. **Always Cache** - Save data to local storage after Firebase load
2. **Graceful Fallback** - Use cached data when network fails
3. **Validate Permissions** - Check features before showing UI
4. **Test Offline** - Enable offline mode in DevTools
5. **Monitor Logs** - Check provider logs for issues

## Migration & Upgrades

### When User Upgrades Tier
1. Backend updates subscription in Firestore
2. Next app sync refreshes subscription
3. App unlocks new features automatically
4. Local cache updates with new tier
5. UI adapts without restart

### When Subscription Expires
1. Validation detects expiration date passed
2. UI shows expiration notice
3. Features restricted to expired tier
4. User prompted to renew
5. Offline access limited to basic features

## Troubleshooting

### User Not Auto-Logging In
**Check**:
- `isAutoLoginEnabled()` returns true
- `getCachedUser()` returns valid user
- `AuthProvider._init()` called on startup
- SharedPreferences accessible

**Fix**:
```dart
// Force refresh
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('auto_login_enabled', true);
```

### Cached Data Not Updating
**Check**:
- Last sync timestamp (should be recent)
- `isCacheStale()` returning true
- Network connection available

**Fix**:
```dart
// Force refresh
await businessProvider.loadUserBusinesses(userId);
```

### Feature Access Restricted
**Check**:
- Current subscription tier
- Subscription expiration date
- `isFeatureAvailable(feature)` return value

**Fix**:
```dart
// Check subscription
if (!businessProvider.isSubscriptionValid()) {
  // Show renewal prompt
}
```

## API Reference

### AuthProvider
```dart
// Auto-login and offline access
Future<void> _initializeLocalStorage()
Future<void> _syncCachedUserWithFirebase(String userId)

// Getters
UserModel? get currentUser
AuthStatus get status
bool get isAuthenticated
```

### BusinessProvider
```dart
// Load and cache
Future<void> loadUserBusinesses(String userId, {String? preferredBusinessId})
Future<void> setCurrentBusinessAndSave(String userId, BusinessModel business)

// Offline access
BusinessModel? getCachedCurrentBusiness()
List<BusinessModel> getCachedBusinesses()
Map<String, dynamic> getCacheStats()

// Cleanup
Future<void> clearCachedBusinessData()
```

### LocalUserStorage
```dart
// Cache operations
Future<bool> saveUser(UserModel user)
UserModel? getCachedUser()
Future<bool> updateCachedUser({...})
Future<bool> clearUser()

// Auto-login
bool isAutoLoginEnabled()
String? getLastLoggedInEmail()
```

### LocalBusinessStorage
```dart
// Save/retrieve
Future<bool> saveBusinessList(List<BusinessModel> businesses)
List<BusinessModel> getCachedBusinesses()
BusinessModel? getCachedBusiness(String businessId)

// Selection
Future<bool> setCurrentBusiness(String businessId)
String? getCurrentBusinessId()
BusinessModel? getCurrentBusiness()

// Cache management
DateTime? getLastSyncTime()
bool isCacheStale({int maxAgeMinutes = 60})
Map<String, dynamic> getCacheStats()
Future<bool> clearAllBusinessData()
```

## Version History

### v1.0.0 - Initial Release
- ✅ User auto-login with local caching
- ✅ Business data caching
- ✅ Subscription tier management
- ✅ Offline access support
- ✅ Automatic sync on app restart

### Planned Features
- Background sync service
- Incremental data sync
- Subscription webhook notifications
- Advanced usage analytics
- Subscription analytics dashboard

